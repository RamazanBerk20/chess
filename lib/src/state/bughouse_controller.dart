import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:chess/src/rust/api/ai.dart';
import 'package:chess/src/rust/api/game.dart';
import 'package:chess/src/state/difficulty.dart';
import 'package:chess/src/state/time_control.dart';

/// The two boards of a Bughouse match.
enum BugBoard { a, b }

BugBoard _other(BugBoard b) => b == BugBoard.a ? BugBoard.b : BugBoard.a;
PieceColor _opp(PieceColor c) =>
    c == PieceColor.white ? PieceColor.black : PieceColor.white;

/// The four seats. Teams: 1 = A-White + B-Black, 2 = A-Black + B-White
/// (partners play opposite colors on opposite boards).
enum BugSeat { aWhite, aBlack, bWhite, bBlack }

BugSeat seatOf(BugBoard board, PieceColor color) =>
    switch ((board, color)) {
      (BugBoard.a, PieceColor.white) => BugSeat.aWhite,
      (BugBoard.a, PieceColor.black) => BugSeat.aBlack,
      (BugBoard.b, PieceColor.white) => BugSeat.bWhite,
      (BugBoard.b, PieceColor.black) => BugSeat.bBlack,
    };

int teamOf(BugSeat seat) =>
    (seat == BugSeat.aWhite || seat == BugSeat.bBlack) ? 1 : 2;

enum BughouseMode { hotSeat, vsAi, lan }

class BugConfig {
  final BughouseMode mode;
  final TimeControlOption tc;

  /// Seats a human controls. The rest are AI (vs-AI); all four in hot-seat; in
  /// LAN, the seats assigned to this device.
  final Set<BugSeat> humanSeats;
  final Difficulty difficulty;

  /// LAN: send a board-tagged move to the host authority (board 0=A, 1=B).
  final void Function(int board, String uci, int whiteMs, int blackMs)? lanSend;

  const BugConfig({
    required this.mode,
    required this.tc,
    required this.humanSeats,
    this.difficulty = Difficulty.medium,
    this.lanSend,
  });
}

class BugResult {
  final int winningTeam; // 1 or 2
  final GameOutcome? reason; // null when reported over the network
  final BugBoard board; // the board that ended
  const BugResult(this.winningTeam, this.reason, this.board);
}

class _Board {
  final ChessGame game;
  int? selected;
  Set<int> targets = {};
  int? handPiece; // reserve piece armed for a drop
  (int, int)? pendingPromo; // (from, to) awaiting a promotion choice
  // Premove chain queued while the opponent (AI/remote) is to move here.
  List<(int, int)> premoves = [];
  int? premoveFrom;
  Set<int> premoveTargets = {};
  final bool flipped;
  _Board(this.game, this.flipped);

  /// Board after the queued premoves (raw relocations) for chained selection.
  List<SquarePiece?> previewBoard() {
    final board = game.view().board;
    if (premoves.isEmpty) return board;
    final out = List<SquarePiece?>.of(board);
    for (final (f, t) in premoves) {
      out[t] = out[f];
      out[f] = null;
    }
    return out;
  }

  Set<int> premoveTargetsAfter(int sq) => game
      .premoveTargetsAfter(
          premoves: [for (final (f, t) in premoves) ...[f, t]], from: sq)
      .toSet();

  void clearPremoves() {
    premoves = [];
    premoveFrom = null;
    premoveTargets = {};
  }
}

/// Drives a two-board Bughouse match locally (hot-seat or vs-AI), holding two
/// [ChessGame]s directly (the global game/clock/AI providers are single-game).
class BughouseController extends ChangeNotifier {
  final BugConfig config;
  late final _Board _a;
  late final _Board _b;

  Timer? _ticker;
  int _lastTickMs = 0;
  BugResult? result;

  final Map<BugBoard, StreamSubscription<AiUpdate>> _aiSubs = {};
  final Map<BugBoard, int> _aiIds = {};
  final Map<BugBoard, Timer> _aiPlayTimers = {};
  final Map<BugBoard, int> _aiDefers = {};
  // Minimum wall-clock between an AI search finishing and its move landing, so a
  // fully-AI board can't blitz to a result before the human plays their board.
  static const int _aiPaceMs = 700;
  // How many extra pace intervals the bot waits while the human is mid-premove
  // (caps the hold so a forgotten selection can't freeze the board forever).
  static const int _aiMaxDefers = 12;
  int _aiCounter = 0;
  bool _disposed = false;

  BughouseController(this.config) {
    final tc = config.tc;
    // Board A oriented White-bottom; Board B Black-bottom so the two boards
    // mirror (partners sit on opposite sides).
    _a = _Board(_makeGame(tc), false);
    _b = _Board(_makeGame(tc), true);
    if (!tc.isInfinite) _startTicker();
    _maybeAi();
  }

  ChessGame _makeGame(TimeControlOption tc) => ChessGame.newVariant(
        variant: GameVariant.bughouse,
        baseMinutes: tc.baseMinutes ?? 0,
        incrementSeconds: tc.incrementSeconds,
        chess960Index: 0,
      );

  _Board _b_(BugBoard b) => b == BugBoard.a ? _a : _b;

  GameView viewOf(BugBoard b) => _b_(b).game.view();
  ClockSnapshot clockOf(BugBoard b) => _b_(b).game.clockSnapshot();
  bool flippedOf(BugBoard b) => _b_(b).flipped;
  int? selectedOf(BugBoard b) => _b_(b).selected;
  Set<int> targetsOf(BugBoard b) => _b_(b).targets;
  int? handPieceOf(BugBoard b) => _b_(b).handPiece;
  (int, int)? pendingPromoOf(BugBoard b) => _b_(b).pendingPromo;

  bool _isHuman(BugSeat seat) =>
      config.mode == BughouseMode.hotSeat || config.humanSeats.contains(seat);

  /// Whether the side to move on `board` is controlled by a human right now.
  bool humanToMove(BugBoard board) {
    if (result != null) return false;
    final v = _b_(board).game.view();
    if (v.status != GameOutcome.ongoing) return false;
    return _isHuman(seatOf(board, v.sideToMove));
  }

  void _clearSel(_Board b) {
    b.selected = null;
    b.targets = {};
    b.handPiece = null;
  }

  // --- Human input -----------------------------------------------------------

  void tapSquare(BugBoard board, int sq) {
    if (result != null) return;
    final b = _b_(board);
    if (b.pendingPromo != null) return;
    final view = b.game.view();
    final color = view.sideToMove;
    if (!_isHuman(seatOf(board, color))) {
      _premoveTap(board, sq); // opponent to move here → queue a premove
      return;
    }

    if (b.handPiece != null) {
      if (b.targets.contains(sq)) {
        _doDrop(board, sq);
      } else {
        _clearSel(b);
        notifyListeners();
      }
      return;
    }

    final piece = view.board[sq];
    final sel = b.selected;
    if (sel == null) {
      if (piece != null && piece.color == color) {
        b.selected = sq;
        b.targets = b.game.legalTargets(from: sq).toSet();
        notifyListeners();
      }
      return;
    }
    if (sq == sel) {
      _clearSel(b);
      notifyListeners();
      return;
    }
    if (b.targets.contains(sq)) {
      _doMove(board, sel, sq);
      return;
    }
    if (piece != null && piece.color == color) {
      b.selected = sq;
      b.targets = b.game.legalTargets(from: sq).toSet();
    } else {
      _clearSel(b);
    }
    notifyListeners();
  }

  void dragMove(BugBoard board, int from, int to) {
    if (result != null) return;
    final b = _b_(board);
    if (b.pendingPromo != null) return;
    final view = b.game.view();
    final color = view.sideToMove;
    if (!_isHuman(seatOf(board, color))) {
      _premoveDrag(board, from, to); // opponent to move here → queue a premove
      return;
    }
    final piece = view.board[from];
    if (piece == null || piece.color != color) return;
    final targets = b.game.legalTargets(from: from).toSet();
    if (!targets.contains(to)) {
      b.selected = from;
      b.targets = targets;
      notifyListeners();
      return;
    }
    _doMove(board, from, to);
  }

  void selectHand(BugBoard board, int piece) {
    if (result != null) return;
    final b = _b_(board);
    if (b.pendingPromo != null) return;
    final color = b.game.view().sideToMove;
    if (!_isHuman(seatOf(board, color))) return;
    final targets = b.game.dropTargets(piece: piece).toSet();
    if (targets.isEmpty) return;
    b.selected = null;
    b.handPiece = piece;
    b.targets = targets;
    notifyListeners();
  }

  void completePromotion(BugBoard board, PieceKind kind) {
    final b = _b_(board);
    final pp = b.pendingPromo;
    if (pp == null) return;
    if (config.mode == BughouseMode.lan) {
      const codes = {
        PieceKind.queen: 'q',
        PieceKind.rook: 'r',
        PieceKind.bishop: 'b',
        PieceKind.knight: 'n',
      };
      _lanSend(board, '${_su(pp.$1)}${_su(pp.$2)}${codes[kind] ?? 'q'}');
      b.pendingPromo = null;
      _clearSel(b);
      notifyListeners();
      return;
    }
    final mover = b.game.view().sideToMove;
    final outcome = b.game.play(from: pp.$1, to: pp.$2, promotion: kind);
    b.pendingPromo = null;
    _clearSel(b);
    if (outcome == MoveOutcome.played) {
      _afterMove(board, mover);
    } else {
      notifyListeners();
    }
  }

  void cancelPromotion(BugBoard board) {
    _b_(board).pendingPromo = null;
    notifyListeners();
  }

  // --- Premove (queue a move while the opponent is to move on a board) --------

  List<(int, int)> premovesOf(BugBoard b) => _b_(b).premoves;
  int? premoveFromOf(BugBoard b) => _b_(b).premoveFrom;
  Set<int> premoveTargetsOf(BugBoard b) => _b_(b).premoveTargets;

  /// The colour we control on `board` that is NOT currently to move (the side a
  /// premove would be for), or null if we don't control the waiting seat.
  PieceColor? _premoveColor(BugBoard board) {
    final waiting = _opp(_b_(board).game.view().sideToMove);
    return _isHuman(seatOf(board, waiting)) ? waiting : null;
  }

  void _premoveTap(BugBoard board, int sq) {
    final my = _premoveColor(board);
    if (my == null) return;
    final b = _b_(board);
    final piece = b.previewBoard()[sq];
    final selFrom = b.premoveFrom;
    if (selFrom == null) {
      if (piece != null && piece.color == my) {
        b.premoveFrom = sq;
        b.premoveTargets = b.premoveTargetsAfter(sq);
      } else {
        b.clearPremoves();
      }
      notifyListeners();
      return;
    }
    if (sq == selFrom) {
      b.premoveFrom = null;
      b.premoveTargets = {};
      notifyListeners();
      return;
    }
    if (b.premoveTargets.contains(sq)) {
      b.premoves = [...b.premoves, (selFrom, sq)];
      b.premoveFrom = null;
      b.premoveTargets = {};
      notifyListeners();
      return;
    }
    if (piece != null && piece.color == my) {
      b.premoveFrom = sq;
      b.premoveTargets = b.premoveTargetsAfter(sq);
    } else {
      b.premoveFrom = null;
      b.premoveTargets = {};
    }
    notifyListeners();
  }

  void _premoveDrag(BugBoard board, int from, int to) {
    final my = _premoveColor(board);
    if (my == null) return;
    final b = _b_(board);
    final piece = b.previewBoard()[from];
    if (piece == null || piece.color != my) return;
    final targets = b.premoveTargetsAfter(from);
    if (targets.contains(to)) {
      b.premoves = [...b.premoves, (from, to)];
      b.premoveFrom = null;
      b.premoveTargets = {};
    } else {
      b.premoveFrom = from;
      b.premoveTargets = targets;
    }
    notifyListeners();
  }

  /// After a move lands on `board`, play the front of our premove chain there if
  /// it is now our turn. Keep the rest for the next reply; drop all if illegal.
  void _tryPremove(BugBoard board) {
    final b = _b_(board);
    if (result != null || b.premoves.isEmpty) return;
    final v = b.game.view();
    if (v.status != GameOutcome.ongoing) {
      b.clearPremoves();
      return;
    }
    if (!_isHuman(seatOf(board, v.sideToMove))) return; // still opponent's turn
    final pm = b.premoves.first;
    final rest = b.premoves.sublist(1);
    final isPromo = (v.board[pm.$1]?.kind == PieceKind.pawn) &&
        (pm.$2 < 8 || pm.$2 >= 56);
    if (config.mode == BughouseMode.lan) {
      _lanSend(board, '${_su(pm.$1)}${_su(pm.$2)}${isPromo ? 'q' : ''}');
      b.premoves = rest;
      b.premoveFrom = null;
      b.premoveTargets = {};
      notifyListeners();
      return;
    }
    final mover = v.sideToMove;
    var outcome = b.game.play(from: pm.$1, to: pm.$2, promotion: null);
    if (outcome == MoveOutcome.needsPromotion) {
      outcome = b.game.play(from: pm.$1, to: pm.$2, promotion: PieceKind.queen);
    }
    if (outcome == MoveOutcome.played) {
      b.premoves = rest;
      b.premoveFrom = null;
      b.premoveTargets = {};
      _afterMove(board, mover);
    } else {
      b.clearPremoves();
      notifyListeners();
    }
  }

  // --- Move application -------------------------------------------------------

  void _doMove(BugBoard board, int from, int to) {
    final b = _b_(board);
    if (config.mode == BughouseMode.lan) {
      // Don't mutate the local mirror — send to the host; its echo applies it.
      final piece = b.game.view().board[from];
      final isPromo =
          piece?.kind == PieceKind.pawn && (to < 8 || to >= 56);
      if (isPromo) {
        b.selected = null;
        b.targets = {};
        b.handPiece = null;
        b.pendingPromo = (from, to);
      } else {
        _lanSend(board, '${_su(from)}${_su(to)}');
        _clearSel(b);
      }
      notifyListeners();
      return;
    }
    final mover = b.game.view().sideToMove;
    final outcome = b.game.play(from: from, to: to, promotion: null);
    switch (outcome) {
      case MoveOutcome.played:
        _clearSel(b);
        _afterMove(board, mover);
      case MoveOutcome.needsPromotion:
        b.selected = null;
        b.targets = {};
        b.handPiece = null;
        b.pendingPromo = (from, to);
        notifyListeners();
      case MoveOutcome.illegal:
        _clearSel(b);
        notifyListeners();
    }
  }

  void _doDrop(BugBoard board, int to) {
    final b = _b_(board);
    final piece = b.handPiece;
    if (piece == null) return;
    if (config.mode == BughouseMode.lan) {
      _lanSend(board, '${const ['P', 'N', 'B', 'R', 'Q'][piece]}@${_su(to)}');
      _clearSel(b);
      notifyListeners();
      return;
    }
    final mover = b.game.view().sideToMove;
    final outcome = b.game.playDrop(piece: piece, to: to);
    _clearSel(b);
    if (outcome == MoveOutcome.played) {
      _afterMove(board, mover);
    } else {
      notifyListeners();
    }
  }

  /// After any successful move: route the captured piece to the partner's
  /// reserve on the other board, check for a match end, then nudge the AI.
  void _afterMove(BugBoard board, PieceColor mover) {
    // A move landed here → any in-progress (uncommitted) premove selection on
    // this board is stale; clear it so its dots don't linger. Keep the queue.
    _b_(board).premoveFrom = null;
    _b_(board).premoveTargets = {};
    final passable = _b_(board).game.lastPassableCapture();
    if (passable != null) {
      // Partner is on the other board, opposite color to the mover.
      _b_(_other(board)).game.giveToHand(color: _opp(mover), piece: passable);
    }
    _checkEnd();
    notifyListeners();
    _maybeAi();
    _tryPremove(board); // it's our turn here now → fire a queued premove
  }

  void _checkEnd() {
    if (result != null) return;
    for (final board in BugBoard.values) {
      final v = _b_(board).game.view();
      if (v.status == GameOutcome.ongoing) continue;
      final loser = _loserColor(v.status, v.sideToMove);
      final losingTeam = teamOf(seatOf(board, loser));
      result = BugResult(losingTeam == 1 ? 2 : 1, v.status, board);
      _ticker?.cancel();
      _ticker = null;
      _cancelAi();
      return;
    }
  }

  /// Which color lost on a finished board. No draws in Bughouse — a stalemated
  /// or otherwise drawn side loses.
  PieceColor _loserColor(GameOutcome status, PieceColor sideToMove) =>
      switch (status) {
        GameOutcome.whiteWins ||
        GameOutcome.whiteWinsOnTime =>
          PieceColor.black,
        GameOutcome.blackWins ||
        GameOutcome.blackWinsOnTime =>
          PieceColor.white,
        _ => sideToMove, // stalemate / repetition / 50-move → side to move loses
      };

  // --- Clock ticker -----------------------------------------------------------

  void _startTicker() {
    _lastTickMs = DateTime.now().millisecondsSinceEpoch;
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_disposed || result != null) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final ms = now - _lastTickMs;
      _lastTickMs = now;
      _a.game.tick(elapsedMs: ms);
      _b.game.tick(elapsedMs: ms);
      _checkEnd();
      notifyListeners();
    });
  }

  // --- AI seats ---------------------------------------------------------------

  void _maybeAi() {
    if (config.mode != BughouseMode.vsAi || result != null || _disposed) return;
    for (final board in BugBoard.values) {
      if (_aiSubs.containsKey(board)) continue;
      final v = _b_(board).game.view();
      if (v.status != GameOutcome.ongoing) continue;
      if (_isHuman(seatOf(board, v.sideToMove))) continue;
      _searchAi(board, v);
    }
  }

  void _searchAi(BugBoard board, GameView v) {
    final g = _b_(board).game;
    final id = ++_aiCounter;
    _aiIds[board] = id;
    final seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    final sub = aiSearch(
      searchId: BigInt.from(id),
      fen: v.fen,
      config: config.difficulty.toConfig(seed),
      history: g.hashHistory(),
      variant: GameVariant.bughouse,
      whiteChecks: 0,
      blackChecks: 0,
      whiteHand: v.whiteHand,
      blackHand: v.blackHand,
      promoted: v.promoted,
    ).listen(
      (u) {
        if (!u.done) return;
        _aiSubs.remove(board);
        _aiIds.remove(board);
        if (_disposed || result != null) return;
        if (u.bestUci.isEmpty) return;
        _scheduleAiPlay(board, u.bestUci);
      },
      onError: (_) {
        _aiSubs.remove(board);
        _aiIds.remove(board);
      },
    );
    _aiSubs[board] = sub;
  }

  /// Pace the bot AND politely wait while the human is actively choosing a
  /// premove on this board, so a fast bot can't snatch its turn mid-selection
  /// (which left the human unable to commit + stale dots on the board).
  void _scheduleAiPlay(BugBoard board, String uci) {
    _aiPlayTimers[board]?.cancel();
    _aiDefers[board] = 0;
    _aiPlayTimers[board] =
        Timer(const Duration(milliseconds: _aiPaceMs), () => _aiPlayTick(board, uci));
  }

  void _aiPlayTick(BugBoard board, String uci) {
    _aiPlayTimers.remove(board);
    if (_disposed || result != null) return;
    final b = _b_(board);
    final gv = b.game.view();
    if (gv.status != GameOutcome.ongoing) return;
    if (_isHuman(seatOf(board, gv.sideToMove))) return;
    // Hold the bot back while the human is mid-premove-selection here (capped).
    if (b.premoveFrom != null && (_aiDefers[board] ?? 0) < _aiMaxDefers) {
      _aiDefers[board] = (_aiDefers[board] ?? 0) + 1;
      _aiPlayTimers[board] =
          Timer(const Duration(milliseconds: _aiPaceMs), () => _aiPlayTick(board, uci));
      return;
    }
    final mover = gv.sideToMove;
    if (b.game.playUci(uci: uci)) {
      _afterMove(board, mover);
    }
  }

  void _cancelAi() {
    for (final s in _aiSubs.values) {
      s.cancel();
    }
    for (final id in _aiIds.values) {
      aiCancel(searchId: BigInt.from(id));
    }
    for (final tmr in _aiPlayTimers.values) {
      tmr.cancel();
    }
    _aiSubs.clear();
    _aiIds.clear();
    _aiPlayTimers.clear();
    _aiDefers.clear();
  }

  // --- LAN (host broadcasts drive these mirrors) ------------------------------

  static String _su(int sq) =>
      '${String.fromCharCode(97 + sq % 8)}${sq ~/ 8 + 1}';

  void _lanSend(BugBoard board, String uci) {
    final snap = _b_(board).game.clockSnapshot();
    config.lanSend?.call(board == BugBoard.a ? 0 : 1, uci, snap.whiteMs, snap.blackMs);
  }

  /// Apply a move the host broadcast (its authority already validated it).
  void applyRemoteMove(int board, String uci) {
    final b = board == 0 ? _a : _b;
    if (b.game.playUci(uci: uci)) {
      _clearSel(b);
      b.premoveFrom = null; // drop any stale in-progress premove selection
      b.premoveTargets = {};
      notifyListeners();
      _tryPremove(board == 0 ? BugBoard.a : BugBoard.b);
    }
  }

  /// Apply a partner feed the host broadcast.
  void applyPass(int board, int color, int piece) {
    final b = board == 0 ? _a : _b;
    b.game.giveToHand(
      color: color == 0 ? PieceColor.white : PieceColor.black,
      piece: const [
        PieceKind.pawn,
        PieceKind.knight,
        PieceKind.bishop,
        PieceKind.rook,
        PieceKind.queen,
      ][piece],
    );
    notifyListeners();
  }

  /// Apply the host's match result.
  void applyResult(int team, int board) {
    result = BugResult(team, null, board == 0 ? BugBoard.a : BugBoard.b);
    _ticker?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _cancelAi();
    super.dispose();
  }
}
