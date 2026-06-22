import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:chess/src/rust/api/four.dart';
import 'package:chess/src/rust/api/game.dart' show MoveOutcome;

enum FourMode { hotSeat, vsBots, lan }

class FourConfig {
  final FourMode mode;
  final FourFormat format;

  /// Seats a human controls (all four in hot-seat; the chosen ones in vs-bots;
  /// the seats assigned to this device in LAN).
  final Set<FourPlayer> humanSeats;

  /// LAN: send a seat-tagged move to the host authority.
  final void Function(int seat, String uci)? lanSend;

  const FourConfig({
    required this.mode,
    required this.format,
    required this.humanSeats,
    this.lanSend,
  });
}

const _seatIndex = {
  FourPlayer.red: 0,
  FourPlayer.blue: 1,
  FourPlayer.yellow: 2,
  FourPlayer.green: 3,
};

/// Drives one 4-player game (hot-seat or vs-bots); turn rotation lives in the
/// engine. Owned by the screen (ChangeNotifier), bypassing the single-game
/// Riverpod providers.
class FourPlayerController extends ChangeNotifier {
  final FourConfig config;
  late final FourGame _game;
  int? selected;
  Set<int> targets = {};
  (int, int)? pendingPromo;
  bool _disposed = false;
  Timer? _botTimer;
  // Premove chain queued while a bot/remote player is to move.
  List<(int, int)> premoves = [];
  int? premoveFrom;
  Set<int> premoveTargets = {};
  int _botDefers = 0;
  static const int _botMaxDefers = 12;

  FourPlayerController(this.config) {
    _game = FourGame.newGame(format: config.format);
    _scheduleBot();
  }

  /// Host-declared result over the network (forfeit/disconnect) overriding the
  /// local mirror.
  String? netResult;

  FourView view() => _game.view();
  String resultString() => netResult ?? _game.view().result;
  bool get isOver => resultString() != 'ongoing';

  bool _isHuman(FourPlayer p) =>
      config.mode == FourMode.hotSeat || config.humanSeats.contains(p);

  bool humanToMove() {
    final v = _game.view();
    return v.result == 'ongoing' && _isHuman(v.turn);
  }

  void tapSquare(int sq) {
    if (isOver || pendingPromo != null) return;
    final v = _game.view();
    if (!_isHuman(v.turn)) {
      _premoveTap(sq); // a bot/remote is to move → queue a premove
      return;
    }
    final piece = v.board[sq];
    if (selected == null) {
      if (piece != null && piece.player == v.turn) {
        selected = sq;
        targets = _game.legalTargets(from: sq).toSet();
        notifyListeners();
      }
      return;
    }
    if (sq == selected) {
      _clear();
      notifyListeners();
      return;
    }
    if (targets.contains(sq)) {
      _doMove(selected!, sq);
      return;
    }
    if (piece != null && piece.player == v.turn) {
      selected = sq;
      targets = _game.legalTargets(from: sq).toSet();
    } else {
      _clear();
    }
    notifyListeners();
  }

  void dragMove(int from, int to) {
    if (isOver || pendingPromo != null) return;
    final v = _game.view();
    if (!_isHuman(v.turn)) {
      _premoveDrag(from, to); // a bot/remote is to move → queue a premove
      return;
    }
    final piece = v.board[from];
    if (piece == null || piece.player != v.turn) return;
    final ts = _game.legalTargets(from: from).toSet();
    if (!ts.contains(to)) {
      selected = from;
      targets = ts;
      notifyListeners();
      return;
    }
    _doMove(from, to);
  }

  void _doMove(int from, int to) {
    if (config.mode == FourMode.lan) {
      // Don't mutate the local mirror — send to the host; its echo applies it.
      final piece = _game.view().board[from];
      if (piece?.kind == FourPieceKind.pawn && _isPromo(piece!.player, to)) {
        selected = null;
        targets = {};
        pendingPromo = (from, to);
      } else {
        _lanSend('${_coordStr(from)}${_coordStr(to)}');
        _clear();
      }
      notifyListeners();
      return;
    }
    final outcome = _game.play(from: from, to: to, promotion: null);
    switch (outcome) {
      case MoveOutcome.played:
        _clear();
        _afterMove();
      case MoveOutcome.needsPromotion:
        selected = null;
        targets = {};
        pendingPromo = (from, to);
        notifyListeners();
      case MoveOutcome.illegal:
        _clear();
        notifyListeners();
    }
  }

  void completePromotion(FourPieceKind kind) {
    final pp = pendingPromo;
    if (pp == null) return;
    if (config.mode == FourMode.lan) {
      const codes = {
        FourPieceKind.queen: 'q',
        FourPieceKind.rook: 'r',
        FourPieceKind.bishop: 'b',
        FourPieceKind.knight: 'n',
      };
      _lanSend('${_coordStr(pp.$1)}${_coordStr(pp.$2)}${codes[kind] ?? 'q'}');
      pendingPromo = null;
      _clear();
      notifyListeners();
      return;
    }
    final outcome = _game.play(from: pp.$1, to: pp.$2, promotion: kind);
    pendingPromo = null;
    _clear();
    if (outcome == MoveOutcome.played) {
      _afterMove();
    } else {
      notifyListeners();
    }
  }

  void cancelPromotion() {
    pendingPromo = null;
    notifyListeners();
  }

  // --- Premove (queue while a bot/remote is to move) -------------------------

  List<FourSquarePiece?> _previewBoard() {
    final board = _game.view().board;
    if (premoves.isEmpty) return board;
    final out = List<FourSquarePiece?>.of(board);
    for (final (f, t) in premoves) {
      out[t] = out[f];
      out[f] = null;
    }
    return out;
  }

  Set<int> _premoveTargetsAfter(int sq) => _game
      .premoveTargetsAfter(
          premoves: [for (final (f, t) in premoves) ...[f, t]], from: sq)
      .toSet();

  void _clearPremoves() {
    premoves = [];
    premoveFrom = null;
    premoveTargets = {};
  }

  void _premoveTap(int sq) {
    final piece = _previewBoard()[sq];
    final selFrom = premoveFrom;
    if (selFrom == null) {
      if (piece != null && _isHuman(piece.player)) {
        premoveFrom = sq;
        premoveTargets = _premoveTargetsAfter(sq);
      } else {
        _clearPremoves();
      }
      notifyListeners();
      return;
    }
    if (sq == selFrom) {
      premoveFrom = null;
      premoveTargets = {};
      notifyListeners();
      return;
    }
    if (premoveTargets.contains(sq)) {
      premoves = [...premoves, (selFrom, sq)];
      premoveFrom = null;
      premoveTargets = {};
      notifyListeners();
      return;
    }
    if (piece != null && _isHuman(piece.player)) {
      premoveFrom = sq;
      premoveTargets = _premoveTargetsAfter(sq);
    } else {
      premoveFrom = null;
      premoveTargets = {};
    }
    notifyListeners();
  }

  void _premoveDrag(int from, int to) {
    final piece = _previewBoard()[from];
    if (piece == null || !_isHuman(piece.player)) return;
    final ts = _premoveTargetsAfter(from);
    if (ts.contains(to)) {
      premoves = [...premoves, (from, to)];
      premoveFrom = null;
      premoveTargets = {};
    } else {
      premoveFrom = from;
      premoveTargets = ts;
    }
    notifyListeners();
  }

  /// When it becomes a human seat's turn, play the front of the chain if it is
  /// that seat's move. Wait if the queued piece's turn hasn't arrived; drop the
  /// chain if its piece is gone or no longer ours.
  void _tryPremove() {
    if (isOver || premoves.isEmpty) return;
    final v = _game.view();
    if (v.result != 'ongoing') {
      _clearPremoves();
      return;
    }
    if (!_isHuman(v.turn)) return;
    final pm = premoves.first;
    final piece = v.board[pm.$1];
    if (piece == null || !_isHuman(piece.player)) {
      _clearPremoves();
      notifyListeners();
      return;
    }
    if (piece.player != v.turn) return; // our piece, but not its turn yet
    final rest = premoves.sublist(1);
    if (config.mode == FourMode.lan) {
      final isPromo =
          piece.kind == FourPieceKind.pawn && _isPromo(piece.player, pm.$2);
      _lanSend('${_coordStr(pm.$1)}${_coordStr(pm.$2)}${isPromo ? 'q' : ''}');
      premoves = rest;
      premoveFrom = null;
      premoveTargets = {};
      notifyListeners();
      return;
    }
    var outcome = _game.play(from: pm.$1, to: pm.$2, promotion: null);
    if (outcome == MoveOutcome.needsPromotion) {
      outcome = _game.play(from: pm.$1, to: pm.$2, promotion: FourPieceKind.queen);
    }
    if (outcome == MoveOutcome.played) {
      premoves = rest;
      premoveFrom = null;
      premoveTargets = {};
      _afterMove();
    } else {
      _clearPremoves();
      notifyListeners();
    }
  }

  void _afterMove() {
    _clear();
    // A move landed → any uncommitted premove selection is stale; clear its
    // dots (keep the committed chain).
    premoveFrom = null;
    premoveTargets = {};
    notifyListeners();
    _scheduleBot();
    _tryPremove(); // a human seat may now be to move → fire a queued premove
  }

  void _clear() {
    selected = null;
    targets = {};
  }

  void _scheduleBot() {
    if (config.mode != FourMode.vsBots || _disposed) return;
    final v = _game.view();
    if (v.result != 'ongoing' || _isHuman(v.turn)) return;
    _botTimer?.cancel();
    _botDefers = 0;
    _botTimer = Timer(const Duration(milliseconds: 300), _botTick);
  }

  void _botTick() {
    if (_disposed) return;
    final v = _game.view();
    if (v.result != 'ongoing' || _isHuman(v.turn)) return;
    // Hold the bot back while the human is mid-premove-selection (capped), so a
    // fast bot can't grab its turn before the human commits the premove.
    if (premoveFrom != null && _botDefers < _botMaxDefers) {
      _botDefers++;
      _botTimer = Timer(const Duration(milliseconds: 300), _botTick);
      return;
    }
    final seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    final uci = _game.botMove(seed: BigInt.from(seed));
    if (uci != null) {
      _game.playUci(uci: uci);
      _afterMove();
    } else {
      notifyListeners();
    }
  }

  // --- LAN (P4) ---
  int seatOf(FourPlayer p) => _seatIndex[p]!;

  static String _coordStr(int sq) =>
      '${String.fromCharCode(97 + sq % 14)}${sq ~/ 14 + 1}';

  bool _isPromo(FourPlayer player, int to) {
    final row = to ~/ 14, col = to % 14;
    return switch (player) {
      FourPlayer.red => row == 10,
      FourPlayer.yellow => row == 3,
      FourPlayer.blue => col == 10,
      FourPlayer.green => col == 3,
    };
  }

  void _lanSend(String uci) {
    config.lanSend?.call(seatOf(_game.view().turn), uci);
  }

  /// Apply a move the host broadcast (its authority already validated it).
  void applyRemoteMove(int seat, String uci) {
    _game.playUci(uci: uci);
    _clear();
    premoveFrom = null; // drop any stale in-progress premove selection
    premoveTargets = {};
    notifyListeners();
    _tryPremove();
  }

  /// Apply the host's match result (forfeit/disconnect override).
  void applyResult(String result) {
    netResult = result;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _botTimer?.cancel();
    super.dispose();
  }
}
