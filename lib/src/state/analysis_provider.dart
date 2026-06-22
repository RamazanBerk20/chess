import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/src/rust/api/analyze.dart';

/// One analyzed ply.
class AnalysisMove {
  final int ply;
  final String uci;
  final String san;
  final int evalCp; // White POV after the move, clamped
  final int mateIn; // 0 = none; signed plies (White mating > 0)
  final int evalBeforeCp; // White POV before the move (best play)
  final int mateBeforeIn;
  final String bestUci;
  final String bestSan; // engine's best move in SAN (for coach text)
  final int cpLoss;
  final String classification;

  const AnalysisMove({
    required this.ply,
    required this.uci,
    required this.san,
    required this.evalCp,
    required this.mateIn,
    required this.evalBeforeCp,
    required this.mateBeforeIn,
    required this.bestUci,
    required this.bestSan,
    required this.cpLoss,
    required this.classification,
  });
}

class AnalysisState {
  final bool running;
  final bool done;
  final int progress;
  final int total;
  final List<AnalysisMove> moves;
  final double whiteAccuracy;
  final double blackAccuracy;

  const AnalysisState({
    this.running = false,
    this.done = false,
    this.progress = 0,
    this.total = 0,
    this.moves = const [],
    this.whiteAccuracy = 0,
    this.blackAccuracy = 0,
  });

  AnalysisState copyWith({
    bool? running,
    bool? done,
    int? progress,
    int? total,
    List<AnalysisMove>? moves,
    double? whiteAccuracy,
    double? blackAccuracy,
  }) =>
      AnalysisState(
        running: running ?? this.running,
        done: done ?? this.done,
        progress: progress ?? this.progress,
        total: total ?? this.total,
        moves: moves ?? this.moves,
        whiteAccuracy: whiteAccuracy ?? this.whiteAccuracy,
        blackAccuracy: blackAccuracy ?? this.blackAccuracy,
      );
}

final analysisProvider =
    NotifierProvider<AnalysisController, AnalysisState>(AnalysisController.new);

class AnalysisController extends Notifier<AnalysisState> {
  StreamSubscription<AnalysisUpdate>? _sub;

  @override
  AnalysisState build() {
    ref.onDispose(() {
      _sub?.cancel();
      analysisCancel();
    });
    return const AnalysisState();
  }

  /// Analyze [moves] (UCI) played from [startFen].
  void run(
    List<String> moves, {
    String startFen =
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    // Depth 6 ≈ 0.3 s/ply on this engine (~25 s for a 40-move game), a good
    // balance of classification quality and responsiveness with the progress
    // bar. Higher depths grow ~5× per level and become impractical per-ply.
    int depth = 6,
  }) {
    _sub?.cancel();
    analysisCancel();
    state = AnalysisState(running: true, total: moves.length);
    final acc = <AnalysisMove>[];
    _sub = analyzeGame(startFen: startFen, moves: moves, depth: depth)
        .listen((u) {
      if (u.done) {
        state = state.copyWith(
          running: false,
          done: true,
          progress: u.total,
          whiteAccuracy: u.whiteAccuracy,
          blackAccuracy: u.blackAccuracy,
        );
        return;
      }
      acc.add(AnalysisMove(
        ply: u.ply,
        uci: u.uci,
        san: u.san,
        evalCp: u.evalCp,
        mateIn: u.mateIn,
        evalBeforeCp: u.evalBeforeCp,
        mateBeforeIn: u.mateBeforeIn,
        bestUci: u.bestUci,
        bestSan: u.bestSan,
        cpLoss: u.cpLoss,
        classification: u.classification,
      ));
      state = state.copyWith(
        progress: u.progress,
        total: u.total,
        moves: List.unmodifiable(acc),
      );
    }, onError: (_) {
      state = state.copyWith(running: false);
    });
  }

  void cancel() {
    analysisCancel();
    _sub?.cancel();
    state = state.copyWith(running: false);
  }
}
