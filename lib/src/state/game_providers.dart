import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' show Uint64List;

import 'package:chess/src/rust/api/game.dart';
import 'package:chess/src/rust/api/net.dart' show netSendMove;
import 'package:chess/src/state/ai_provider.dart';
import 'package:chess/src/state/clock_provider.dart';
import 'package:chess/src/state/game_mode.dart';
import 'package:chess/src/state/l10n_labels.dart';
import 'package:chess/src/state/saved_games.dart';
import 'package:chess/src/state/settings.dart';
import 'package:chess/src/state/time_control.dart';

/// UI state for a single same-device game. The authoritative chess state lives
/// in the Rust [ChessGame]; this holds the current rendered [GameView] plus
/// transient interaction state (selection, hint targets, board orientation).
class GameUiState {
  final GameView view;
  final int? selected;
  final Set<int> targets;
  final bool flipped; // manual flip (used when autoFlip is off)
  final bool autoFlip; // keep the side to move on the bottom
  final (int, int)? pendingPromotion; // (from, to) awaiting a piece choice
  final bool animateLast; // animate the last move's slide (false after undo)
  // Premoves (vs-AI): a queued chain of moves, played one per opponent reply.
  final List<(int, int)> premoves; // committed premove chain (in order)
  final int? premoveFrom; // square selected while choosing the next premove
  final Set<int> premoveTargets; // candidate destinations for that selection
  // A non-board outcome (resignation, draw agreement, disconnect, flag-fall).
  final String? overlayResult;
  // Crazyhouse: the reserve piece selected for dropping (0=Pawn..4=Queen), if any.
  final int? handPiece;

  const GameUiState({
    required this.view,
    this.selected,
    this.targets = const {},
    this.flipped = false,
    this.autoFlip = false,
    this.pendingPromotion,
    this.animateLast = false,
    this.premoves = const [],
    this.premoveFrom,
    this.premoveTargets = const {},
    this.overlayResult,
    this.handPiece,
  });

  /// Whether the board should be drawn with Black at the bottom.
  bool get isFlipped =>
      autoFlip ? view.sideToMove == PieceColor.black : flipped;

  bool get isOver =>
      view.status != GameOutcome.ongoing || overlayResult != null;

  /// Input must be refused while a promotion choice is outstanding.
  bool get isBusy => pendingPromotion != null;
}

/// A custom start position (FEN) for "Play from Position"; null = standard start.
/// Setup screens set this (null for normal games) before building the game.
final customStartFenProvider =
    NotifierProvider<CustomStartFenController, String?>(
        CustomStartFenController.new);

class CustomStartFenController extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? fen) => state = fen;
}

/// The chess variant for the next game (Standard for normal chess). Setup
/// screens set this before building the game.
final selectedVariantProvider =
    NotifierProvider<SelectedVariantController, GameVariant>(
        SelectedVariantController.new);

class SelectedVariantController extends Notifier<GameVariant> {
  @override
  GameVariant build() => GameVariant.standard;
  void set(GameVariant v) => state = v;
}

final gameControllerProvider =
    NotifierProvider<GameController, GameUiState>(GameController.new);

class GameController extends Notifier<GameUiState> {
  late ChessGame _game;
  String? _startFen; // the position this game (and any rematch) starts from
  GameVariant _variant = GameVariant.standard;

  @override
  GameUiState build() {
    final tc = ref.watch(selectedTimeControlProvider);
    _startFen = ref.read(customStartFenProvider);
    _variant = ref.read(selectedVariantProvider);
    _game = _makeStart(tc);
    final mode = ref.read(gameModeProvider);
    final flipped = mode.lan ? mode.lanMyColor == PieceColor.black : false;
    return GameUiState(view: _game.view(), flipped: flipped);
  }

  ChessGame _make(TimeControlOption tc) {
    return tc.isInfinite
        ? ChessGame.newGame()
        : ChessGame.newTimed(
            baseMinutes: tc.baseMinutes!,
            incrementSeconds: tc.incrementSeconds,
          );
  }

  /// Build the game from the custom start FEN if one is set ("Play from
  /// Position"), else a normal start. Falls back to a normal game on a bad FEN.
  ChessGame _makeStart(TimeControlOption tc) {
    final fen = _startFen;
    if (fen != null) {
      try {
        return ChessGame.fromFen(fen: fen);
      } catch (_) {/* fall through to a normal game */}
    }
    if (_variant != GameVariant.standard) {
      return ChessGame.newVariant(
        variant: _variant,
        baseMinutes: tc.baseMinutes ?? 0,
        incrementSeconds: tc.incrementSeconds,
        chess960Index:
            _variant == GameVariant.chess960 ? Random().nextInt(960) : 0,
      );
    }
    return _make(tc);
  }

  /// Cheap clock-only snapshot for the clock UI.
  ClockSnapshot clockSnapshotNow() => _game.clockSnapshot();

  /// Position-hash history (for the AI's repetition avoidance).
  Uint64List hashHistory() => _game.hashHistory();

  /// Fog of War: the squares the appropriate viewer can see (null off-fog).
  /// Viewer = the human (vs-AI), my colour (LAN), or the side to move (hot-seat).
  Set<int>? fogMask() {
    if (state.view.variant != GameVariant.fogOfWar) return null;
    final mode = ref.read(gameModeProvider);
    final PieceColor viewer;
    if (mode.vsAi) {
      viewer = mode.aiColor == PieceColor.white
          ? PieceColor.black
          : PieceColor.white;
    } else if (mode.lan) {
      viewer = mode.lanMyColor ?? PieceColor.white;
    } else {
      viewer = state.view.sideToMove;
    }
    return _game.visibleSquares(viewer: viewer).toSet();
  }

  /// Advance the running clock by [elapsedMs]; returns the new clock snapshot.
  /// When a flag falls, refreshes full state once so the board shows the result.
  ClockSnapshot tickClock(int elapsedMs) {
    if (state.isOver) return _game.clockSnapshot();
    _game.tick(elapsedMs: elapsedMs);
    final snap = _game.clockSnapshot();
    if (snap.over) {
      state = GameUiState(
        view: _game.view(),
        selected: state.selected,
        targets: state.targets,
        flipped: state.flipped,
        autoFlip: state.autoFlip,
        pendingPromotion: state.pendingPromotion,
        animateLast: state.animateLast,
        premoves: state.premoves,
        premoveFrom: state.premoveFrom,
        premoveTargets: state.premoveTargets,
        overlayResult: state.overlayResult,
      );
    }
    return snap;
  }

  GameUiState _idle({
    int? selected,
    Set<int> targets = const {},
    (int, int)? pending,
    bool? animateLast,
    bool keepPremove = true,
    List<(int, int)>? premoves,
    String? overlayResult,
  }) {
    return GameUiState(
      view: _game.view(),
      selected: selected,
      targets: targets,
      flipped: state.flipped,
      autoFlip: state.autoFlip,
      pendingPromotion: pending,
      // Preserve the slide flag across non-move changes so an in-flight slide
      // isn't cut short by a selection; callers override on play/undo.
      animateLast: animateLast ?? state.animateLast,
      // Preserve the queued premove chain across the opponent's move; clear when
      // it is executed/discarded. `premoves` overrides; else `keepPremove` keeps
      // the current chain. Premove selection (from/targets) ends on any idle.
      premoves: premoves ?? (keepPremove ? state.premoves : const []),
      overlayResult: overlayResult ?? state.overlayResult,
    );
  }

  /// Build a premove selection/queue state. `premoves` defaults to the current
  /// chain; `from`/`targets` describe the in-progress next-premove selection.
  GameUiState _premoveState({
    List<(int, int)>? premoves,
    int? from,
    Set<int> targets = const {},
  }) {
    return GameUiState(
      view: _game.view(),
      flipped: state.flipped,
      autoFlip: state.autoFlip,
      animateLast: state.animateLast,
      premoves: premoves ?? state.premoves,
      premoveFrom: from,
      premoveTargets: targets,
      overlayResult: state.overlayResult,
    );
  }

  /// The board as it would look after the queued premoves (raw relocations),
  /// so a chained premove is selected/rendered from the right squares.
  List<SquarePiece?> _previewBoard() {
    final board = state.view.board;
    if (state.premoves.isEmpty) return board;
    final b = List<SquarePiece?>.of(board);
    for (final (f, t) in state.premoves) {
      b[t] = b[f];
      b[f] = null;
    }
    return b;
  }

  /// Flattened [f0,t0,f1,t1,…] of the queued premoves for the Rust bridge.
  List<int> _flatPremoves() =>
      [for (final (f, t) in state.premoves) ...[f, t]];

  /// Premove targets for `sq` on the board after the queued premoves.
  Set<int> _premoveTargetsAfter(int sq) =>
      _game.premoveTargetsAfter(premoves: _flatPremoves(), from: sq).toSet();

  bool _isHumanTurn() {
    final mode = ref.read(gameModeProvider);
    if (mode.vsAi) return state.view.sideToMove != mode.aiColor;
    if (mode.lan) return state.view.sideToMove == mode.lanMyColor;
    return true;
  }

  PieceColor? _humanColor() {
    final mode = ref.read(gameModeProvider);
    if (mode.vsAi) {
      return mode.aiColor == PieceColor.white
          ? PieceColor.black
          : PieceColor.white;
    }
    if (mode.lan) return mode.lanMyColor;
    return null;
  }

  void newGame() {
    // Stop any in-flight AI search so it can't land a stale move on the new game.
    ref.read(aiControllerProvider.notifier).cancel();
    _game = _makeStart(ref.read(selectedTimeControlProvider));
    state = GameUiState(
      view: _game.view(),
      flipped: state.flipped,
      autoFlip: state.autoFlip,
    );
    ref.invalidate(clockProvider); // restart the ticker for the new game
  }

  void undo() {
    if (state.isBusy) return;
    final mode = ref.read(gameModeProvider);
    if (mode.lan) return; // can't take back networked moves
    if (mode.vsAi) {
      // Take back a full round (AI reply + your move) so it stays your turn and
      // the engine doesn't immediately move again. Needs both plies present.
      ref.read(aiControllerProvider.notifier).cancel();
      if (state.view.sanMoves.length >= 2) {
        _game.undo(); // AI reply
        _game.undo(); // your move
        state = _idle(animateLast: false, keepPremove: false);
        ref.invalidate(clockProvider); // restart the ticker (also after a flag-fall)
      }
      return;
    }
    if (_game.undo()) {
      state = _idle(animateLast: false);
      ref.invalidate(clockProvider);
    }
  }

  void toggleFlip() {
    if (state.isBusy) return;
    state = GameUiState(
      view: state.view,
      selected: state.selected,
      targets: state.targets,
      flipped: !state.flipped,
      autoFlip: false,
      pendingPromotion: state.pendingPromotion,
      animateLast: state.animateLast,
      premoves: state.premoves,
      premoveFrom: state.premoveFrom,
      premoveTargets: state.premoveTargets,
      overlayResult: state.overlayResult,
    );
  }

  void toggleAutoFlip() {
    if (state.isBusy) return;
    state = GameUiState(
      view: state.view,
      selected: state.selected,
      targets: state.targets,
      flipped: state.flipped,
      autoFlip: !state.autoFlip,
      pendingPromotion: state.pendingPromotion,
      animateLast: state.animateLast,
      premoves: state.premoves,
      premoveFrom: state.premoveFrom,
      premoveTargets: state.premoveTargets,
      overlayResult: state.overlayResult,
    );
  }

  /// Tap-to-move handler.
  void tapSquare(int sq) {
    if (state.isOver || state.isBusy) return;
    if (!_isHumanTurn()) {
      // Premove during the opponent's turn (vs-AI or LAN). No-op in hot-seat:
      // _humanColor() is null there and every turn is already "yours".
      _premoveTap(sq);
      return;
    }
    // Crazyhouse: a reserve piece is armed — tap a highlighted square to drop it.
    if (state.handPiece != null) {
      if (state.targets.contains(sq)) {
        dropPiece(sq);
      } else {
        state = _idle();
      }
      return;
    }
    final view = state.view;
    final piece = view.board[sq];
    final sel = state.selected;

    if (sel == null) {
      if (piece != null && piece.color == view.sideToMove) {
        state = _idle(selected: sq, targets: _game.legalTargets(from: sq).toSet());
      }
      return;
    }
    if (sq == sel) {
      state = _idle();
      return;
    }
    if (state.targets.contains(sq)) {
      _attempt(sel, sq);
      return;
    }
    if (piece != null && piece.color == view.sideToMove) {
      state = _idle(selected: sq, targets: _game.legalTargets(from: sq).toSet());
    } else {
      state = _idle();
    }
  }

  /// Premove tap handler (used during the opponent's turn).
  void _premoveTap(int sq) {
    final hc = _humanColor();
    if (hc == null) return;
    // Select/render from the board as it will look after the queued premoves,
    // so the same piece can be chained move after move.
    final piece = _previewBoard()[sq];
    final selFrom = state.premoveFrom;

    if (selFrom == null) {
      if (piece != null && piece.color == hc) {
        state = _premoveState(from: sq, targets: _premoveTargetsAfter(sq));
      } else {
        state = _premoveState(premoves: const []); // tap empty/enemy → clear chain
      }
      return;
    }
    if (sq == selFrom) {
      state = _premoveState(); // cancel the in-progress selection (keep chain)
      return;
    }
    if (state.premoveTargets.contains(sq)) {
      state = _premoveState(premoves: [...state.premoves, (selFrom, sq)]); // queue
      return;
    }
    if (piece != null && piece.color == hc) {
      state = _premoveState(from: sq, targets: _premoveTargetsAfter(sq));
    } else {
      state = _premoveState(); // cancel selection, keep the chain
    }
  }

  /// Drag-to-move handler (drop `from` piece onto `to`).
  void dragMove(int from, int to) {
    if (state.isOver || state.isBusy) return;
    if (!_isHumanTurn()) {
      // Premove during the opponent's turn (vs-AI or LAN; no-op in hot-seat).
      final hc = _humanColor();
      final piece = _previewBoard()[from];
      if (hc != null && piece != null && piece.color == hc) {
        // Validate the destination like the tap path, so no bogus premove
        // highlight is shown for a move that can never fire.
        final targets = _premoveTargetsAfter(from);
        if (targets.contains(to)) {
          state = _premoveState(premoves: [...state.premoves, (from, to)]);
        } else {
          state = _premoveState(from: from, targets: targets);
        }
      }
      return;
    }
    final piece = state.view.board[from];
    if (piece == null || piece.color != state.view.sideToMove) return;
    if (!_game.legalTargets(from: from).contains(to)) {
      state = _idle(selected: from, targets: _game.legalTargets(from: from).toSet());
      return;
    }
    _attempt(from, to);
  }

  /// Crazyhouse: arm a reserve piece for dropping (highlights legal squares).
  void selectHand(int piece) {
    if (state.isOver || state.isBusy || !_isHumanTurn()) return;
    final targets = _game.dropTargets(piece: piece).toSet();
    if (targets.isEmpty) return;
    state = GameUiState(
      view: _game.view(),
      flipped: state.flipped,
      autoFlip: state.autoFlip,
      handPiece: piece,
      targets: targets,
    );
  }

  /// Crazyhouse: drop the armed reserve piece onto `to`.
  void dropPiece(int to) {
    final piece = state.handPiece;
    if (piece == null) return;
    final clock = ref.read(clockProvider.notifier);
    clock.flushElapsed();
    if (state.isOver) {
      state = _idle();
      clock.refreshSnapshot();
      return;
    }
    final outcome = _game.playDrop(piece: piece, to: to);
    state = _idle(animateLast: false);
    if (outcome == MoveOutcome.played) {
      // Send the drop to the LAN peer (no-op off-LAN): UCI "N@e4" form.
      _afterLocalMove('${const ['P', 'N', 'B', 'R', 'Q'][piece]}@${_su(to)}');
      _feedback();
    }
    clock.refreshSnapshot();
  }

  void _attempt(int from, int to) {
    final clock = ref.read(clockProvider.notifier);
    clock.flushElapsed(); // charge the mover's time at the move instant
    if (state.isOver) {
      // The mover flagged while thinking — the move doesn't count.
      state = _idle();
      clock.refreshSnapshot();
      return;
    }
    final outcome = _game.play(from: from, to: to, promotion: null);
    switch (outcome) {
      case MoveOutcome.played:
        state = _idle(animateLast: true);
        _afterLocalMove('${_su(from)}${_su(to)}');
        _feedback();
      case MoveOutcome.needsPromotion:
        state = _idle(pending: (from, to));
      case MoveOutcome.illegal:
        state = _idle();
    }
    clock.refreshSnapshot();
  }

  /// Apply a move chosen by the AI (UCI form), charging its think time.
  void aiPlayUci(String uci) {
    final clock = ref.read(clockProvider.notifier);
    clock.flushElapsed();
    if (state.isOver) {
      state = _idle();
      clock.refreshSnapshot();
      return;
    }
    if (_game.playUci(uci: uci)) {
      state = _idle(animateLast: true);
      _feedback();
    }
    clock.refreshSnapshot();
    _tryExecutePremove();
  }

  /// After the opponent moves, play the front of the premove chain if it is now
  /// legal; keep the rest for the next reply. If it's no longer legal, the chain
  /// is broken — discard all of it.
  void _tryExecutePremove() {
    if (state.premoves.isEmpty || state.isOver || !_isHumanTurn()) return;
    final pm = state.premoves.first;
    final rest = state.premoves.sublist(1);
    final clock = ref.read(clockProvider.notifier);
    clock.flushElapsed();
    if (state.isOver) {
      state = _idle(premoves: const []);
      clock.refreshSnapshot();
      return;
    }
    var outcome = _game.play(from: pm.$1, to: pm.$2, promotion: null);
    var promoted = false;
    if (outcome == MoveOutcome.needsPromotion) {
      // Premove promotions auto-queen (standard behaviour).
      outcome = _game.play(from: pm.$1, to: pm.$2, promotion: PieceKind.queen);
      promoted = true;
    }
    if (outcome == MoveOutcome.played) {
      state = _idle(premoves: rest, animateLast: true);
      // Relay to the LAN peer (no-op off-LAN); auto-queen needs the promo char.
      _afterLocalMove('${_su(pm.$1)}${_su(pm.$2)}${promoted ? 'q' : ''}');
      clock.refreshSnapshot();
      _feedback();
    } else {
      state = _idle(premoves: const [], animateLast: false);
      clock.refreshSnapshot();
    }
  }

  void completePromotion(PieceKind kind) {
    final p = state.pendingPromotion;
    if (p == null) return;
    final clock = ref.read(clockProvider.notifier);
    clock.flushElapsed();
    if (state.isOver) {
      state = _idle();
      clock.refreshSnapshot();
      return;
    }
    _game.play(from: p.$1, to: p.$2, promotion: kind);
    state = _idle(animateLast: true);
    clock.refreshSnapshot();
    _afterLocalMove('${_su(p.$1)}${_su(p.$2)}${_promoChar(kind)}');
  }

  void cancelPromotion() {
    state = _idle();
  }

  // ---- LAN ----

  void _afterLocalMove(String uci) {
    if (!ref.read(gameModeProvider).lan) return;
    final snap = _game.clockSnapshot();
    netSendMove(uci: uci, whiteMs: snap.whiteMs, blackMs: snap.blackMs);
  }

  /// Move sound + haptic feedback, gated by settings. Uses the last SAN to
  /// distinguish check/mate (alert) from a normal move/capture (click).
  void _feedback() {
    final s = ref.read(settingsProvider);
    if (s.haptics) HapticFeedback.lightImpact();
    if (!s.soundOn) return;
    final sans = state.view.sanMoves;
    if (sans.isEmpty) return;
    final last = sans.last;
    if (last.contains('#') || last.contains('+')) {
      SystemSound.play(SystemSoundType.alert);
    } else {
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Apply a move received from the LAN peer (already validated in Rust) and
  /// reconcile the clock from the message.
  void lanApplyRemote(String uci, int whiteMs, int blackMs) {
    if (state.isOver) return;
    if (_game.playUci(uci: uci)) {
      _game.setClockMs(whiteMs: whiteMs, blackMs: blackMs);
      state = _idle(animateLast: true);
      ref.read(clockProvider.notifier).resetAndRefresh();
      _feedback();
      _tryExecutePremove(); // fire a queued premove now that it's our turn
    } else {
      // The peer sent a move our board rejects — the positions have diverged.
      // Abort loudly instead of silently freezing on a stale board.
      lanSetResult(LanResultCode.boardDesync);
    }
  }

  /// Show a non-board result (resignation, draw agreed, disconnect).
  void lanSetResult(String text) {
    state = _idle(overlayResult: text);
  }

  /// Moves played so far (UCI) — for post-game analysis.
  List<String> movesUci() => _game.moveHistoryUci();

  /// The custom start FEN this game began from (null = standard start) — used
  /// for PGN export of games started via "Play from Position".
  String? get startFen => _startFen;

  // ---- Saved games ----

  /// Persist the current game's moves under [name].
  void saveGame(String name) {
    final moves = _game.moveHistoryUci();
    if (moves.isEmpty) return;
    final now = DateTime.now();
    final stamp = now.toString().split('.').first;
    ref.read(savedGamesProvider.notifier).add(SavedGame(
          id: now.microsecondsSinceEpoch.toString(),
          name: name.trim().isEmpty ? 'Game $stamp' : name.trim(),
          moves: moves,
          createdAt: stamp,
        ));
  }

  /// Replay a saved move list onto the current (freshly built) game. The caller
  /// invalidates this provider with an infinite time control first. Returns
  /// false if a move was illegal (corrupt save) — replay stops at that point.
  bool loadGame(List<String> moves) {
    var ok = true;
    for (final u in moves) {
      if (!_game.playUci(uci: u)) {
        ok = false;
        break; // don't apply later plies onto a desynced position
      }
    }
    state = GameUiState(view: _game.view());
    ref.invalidate(clockProvider);
    return ok;
  }

  static String _su(int sq) =>
      '${String.fromCharCode(97 + sq % 8)}${String.fromCharCode(49 + sq ~/ 8)}';

  static String _promoChar(PieceKind k) => switch (k) {
        PieceKind.queen => 'q',
        PieceKind.rook => 'r',
        PieceKind.bishop => 'b',
        PieceKind.knight => 'n',
        _ => 'q',
      };
}
