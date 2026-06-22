import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/src/rust/api/ai.dart';
import 'package:chess/src/state/game_providers.dart';

/// Live AI search progress (streamed from the off-thread engine).
class AiThinking {
  final bool active;
  final int depth;
  final int scoreCp;
  final String bestUci;
  final List<String> pv;

  const AiThinking({
    this.active = false,
    this.depth = 0,
    this.scoreCp = 0,
    this.bestUci = '',
    this.pv = const [],
  });
}

final aiControllerProvider =
    NotifierProvider<AiController, AiThinking>(AiController.new);

class AiController extends Notifier<AiThinking> {
  StreamSubscription<AiUpdate>? _sub;
  int _id = 0;

  @override
  AiThinking build() {
    ref.onDispose(() {
      _sub?.cancel();
      if (_id > 0) aiCancel(searchId: BigInt.from(_id));
    });
    return const AiThinking();
  }

  /// Ask the engine to choose + play a move for the side to move.
  void requestMove({required AiConfigDto config}) {
    final game = ref.read(gameControllerProvider);
    if (game.isOver || state.active) return;
    final view = game.view;
    final history = ref.read(gameControllerProvider.notifier).hashHistory();
    _stopStream();
    final id = ++_id;
    state = const AiThinking(active: true);
    _sub = aiSearch(
      searchId: BigInt.from(id),
      fen: view.fen,
      config: config,
      history: history,
      variant: view.variant,
      whiteChecks: view.whiteChecks,
      blackChecks: view.blackChecks,
      whiteHand: view.whiteHand,
      blackHand: view.blackHand,
      promoted: view.promoted,
    ).listen(
      (u) {
        if (u.done) {
          if (u.bestUci.isNotEmpty) {
            ref.read(gameControllerProvider.notifier).aiPlayUci(u.bestUci);
          }
          state = const AiThinking();
          _sub = null;
        } else {
          state = AiThinking(
            active: true,
            depth: u.depth,
            scoreCp: u.scoreCp,
            bestUci: u.bestUci,
            pv: u.pv,
          );
        }
      },
      onError: (_) => state = const AiThinking(),
      onDone: () {
        if (state.active) state = const AiThinking();
      },
    );
  }

  void cancel() {
    _stopStream();
    state = const AiThinking();
  }

  void _stopStream() {
    if (_sub != null) {
      aiCancel(searchId: BigInt.from(_id));
      _sub?.cancel();
      _sub = null;
    }
  }
}
