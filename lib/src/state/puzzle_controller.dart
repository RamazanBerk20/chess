import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/src/rust/api/game.dart';
import 'package:chess/src/state/puzzle_model.dart';
import 'package:chess/src/state/puzzle_progress.dart';

enum PuzzleStatus { solving, wrong, solved }

class PuzzleUiState {
  final int index;
  final Puzzle puzzle;
  final GameView view;
  final bool flipped;
  final int? selected;
  final Set<int> targets;
  final PuzzleStatus status;
  final int hintLevel;
  final int solvedCount;
  final int total;
  final int bestStreak;
  final int currentStreak;
  final bool alreadySolved;

  const PuzzleUiState({
    required this.index,
    required this.puzzle,
    required this.view,
    required this.flipped,
    required this.status,
    required this.solvedCount,
    required this.total,
    required this.bestStreak,
    required this.currentStreak,
    required this.alreadySolved,
    this.selected,
    this.targets = const {},
    this.hintLevel = 0,
  });
}

final puzzleControllerProvider =
    AsyncNotifierProvider<PuzzleController, PuzzleUiState>(PuzzleController.new);

class PuzzleController extends AsyncNotifier<PuzzleUiState> {
  late List<Puzzle> _puzzles;
  late PuzzleProgress _progress;
  ChessGame? _game;
  int _index = 0;
  int _moveIndex = 0;
  int _epoch = 0;
  int _currentStreak = 0;

  @override
  Future<PuzzleUiState> build() async {
    _puzzles = await loadPuzzles();
    if (_puzzles.isEmpty) {
      throw StateError('No puzzles bundled');
    }
    _progress = await loadPuzzleProgress();
    _currentStreak = 0;
    _index = _progress.currentIndex.clamp(0, _puzzles.length - 1);
    return _load(_index);
  }

  Puzzle get _cur => _puzzles[_index];
  bool get _flipped => _cur.sideToMove == 'black';
  PieceColor get _playerColor =>
      _cur.sideToMove == 'white' ? PieceColor.white : PieceColor.black;

  PuzzleUiState _load(int i) {
    _index = i;
    _moveIndex = 0;
    _epoch++; // invalidate any pending opponent-reply callback (e.g. on retry)
    _game = ChessGame.fromFen(fen: _puzzles[i].fen);
    return _build(PuzzleStatus.solving);
  }

  PuzzleUiState _build(
    PuzzleStatus status, {
    int? selected,
    Set<int> targets = const {},
    int hintLevel = 0,
  }) {
    return PuzzleUiState(
      index: _index,
      puzzle: _cur,
      view: _game!.view(),
      flipped: _flipped,
      status: status,
      selected: selected,
      targets: targets,
      hintLevel: hintLevel,
      solvedCount: _progress.solvedIds.length,
      total: _puzzles.length,
      bestStreak: _progress.bestStreak,
      currentStreak: _currentStreak,
      alreadySolved: _progress.solvedIds.contains(_cur.id),
    );
  }

  void tapSquare(int sq) {
    final st = state.value;
    if (st == null || st.status == PuzzleStatus.solved) return;
    if (_game!.view().sideToMove != _playerColor) return;

    final view = _game!.view();
    final piece = view.board[sq];
    final sel = st.selected;

    if (sel == null) {
      if (piece != null && piece.color == _playerColor) {
        state = AsyncData(_build(PuzzleStatus.solving,
            selected: sq, targets: _game!.legalTargets(from: sq).toSet()));
      }
      return;
    }
    if (sq == sel) {
      state = AsyncData(_build(PuzzleStatus.solving));
      return;
    }
    if (st.targets.contains(sq)) {
      _attempt(sel, sq);
      return;
    }
    if (piece != null && piece.color == _playerColor) {
      state = AsyncData(_build(PuzzleStatus.solving,
          selected: sq, targets: _game!.legalTargets(from: sq).toSet()));
    } else {
      state = AsyncData(_build(PuzzleStatus.solving));
    }
  }

  void dragMove(int from, int to) {
    final st = state.value;
    if (st == null || st.status == PuzzleStatus.solved) return;
    if (_game!.view().sideToMove != _playerColor) return;
    final piece = _game!.view().board[from];
    if (piece == null || piece.color != _playerColor) return;
    if (!_game!.legalTargets(from: from).contains(to)) {
      state = AsyncData(_build(PuzzleStatus.solving,
          selected: from, targets: _game!.legalTargets(from: from).toSet()));
      return;
    }
    _attempt(from, to);
  }

  void _attempt(int from, int to) {
    final expected = _cur.solution[_moveIndex];
    if (from == _sq(expected, 0) && to == _sq(expected, 2)) {
      final promo = expected.length >= 5 ? _promo(expected[4]) : null;
      _game!.play(from: from, to: to, promotion: promo);
      _moveIndex++;
      if (_moveIndex >= _cur.solution.length) {
        _markSolved();
        return;
      }
      // Show the player's move, then auto-play the opponent's reply.
      state = AsyncData(_build(PuzzleStatus.solving));
      _scheduleOpponentReply();
      return;
    }

    // Not the recorded move — accept it anyway if it delivers checkmate (an
    // alternative mate solves the puzzle, matching Lichess).
    var outcome = _game!.play(from: from, to: to, promotion: null);
    if (outcome == MoveOutcome.needsPromotion) {
      outcome = _game!.play(from: from, to: to, promotion: PieceKind.queen);
    }
    if (outcome == MoveOutcome.played) {
      final st = _game!.view().status;
      if (st == GameOutcome.whiteWins || st == GameOutcome.blackWins) {
        _markSolved();
        return;
      }
      _game!.undo(); // not a mate — revert the trial move
    }

    // Legal but not a solving move: mark wrong, let the user retry.
    _currentStreak = 0;
    _progress = _progress.copyWith(
      attemptedIds: {..._progress.attemptedIds, _cur.id},
    );
    savePuzzleProgress(_progress);
    state = AsyncData(_build(PuzzleStatus.wrong));
  }

  void _scheduleOpponentReply() {
    final epoch = _epoch; // bail if the puzzle reloads/retries/changes meanwhile
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_epoch != epoch || _game == null) return;
      if (_moveIndex >= _cur.solution.length) return;
      _game!.playUci(uci: _cur.solution[_moveIndex]);
      _moveIndex++;
      try {
        if (_moveIndex >= _cur.solution.length) {
          _markSolved();
        } else {
          state = AsyncData(_build(PuzzleStatus.solving));
        }
      } catch (_) {
        // Controller disposed mid-delay; ignore.
      }
    });
  }

  void _markSolved() {
    final firstSolve = !_progress.solvedIds.contains(_cur.id);
    _currentStreak++;
    var best = _progress.bestStreak;
    if (_currentStreak > best) best = _currentStreak;
    _progress = _progress.copyWith(
      solvedIds: {..._progress.solvedIds, _cur.id},
      attemptedIds: {..._progress.attemptedIds, _cur.id},
      bestStreak: best,
    );
    savePuzzleProgress(_progress);
    if (!firstSolve) {
      // re-solve still counts toward streak/display
    }
    state = AsyncData(_build(PuzzleStatus.solved));
  }

  void hint() {
    final st = state.value;
    if (st == null || st.status == PuzzleStatus.solved) return;
    if (_game!.view().sideToMove != _playerColor) return;
    final level = (st.hintLevel + 1).clamp(1, 2);
    final expected = _cur.solution[_moveIndex];
    final from = _sq(expected, 0);
    if (level == 1) {
      state = AsyncData(
          _build(PuzzleStatus.solving, selected: from, hintLevel: 1));
    } else {
      state = AsyncData(_build(PuzzleStatus.solving,
          selected: from, targets: {_sq(expected, 2)}, hintLevel: 2));
    }
  }

  void retry() {
    state = AsyncData(_load(_index));
  }

  void next() {
    if (_index < _puzzles.length - 1) _go(_index + 1);
  }

  void prev() {
    if (_index > 0) _go(_index - 1);
  }

  void _go(int i) {
    _progress = _progress.copyWith(currentIndex: i);
    savePuzzleProgress(_progress);
    state = AsyncData(_load(i));
  }

  static int _sq(String uci, int i) =>
      (uci.codeUnitAt(i + 1) - 49) * 8 + (uci.codeUnitAt(i) - 97);

  static PieceKind? _promo(String c) => switch (c) {
        'q' => PieceKind.queen,
        'r' => PieceKind.rook,
        'b' => PieceKind.bishop,
        'n' => PieceKind.knight,
        _ => null,
      };
}
