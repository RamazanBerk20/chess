import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/src/rust/api/game.dart';
import 'package:chess/src/state/game_providers.dart';
import 'package:chess/src/state/time_control.dart';

/// Drives the clock countdown on a 100ms timer, decoupled from the board so
/// ticks don't rebuild the board (which could interrupt an in-progress drag).
/// Null state means there is no clock (Infinite time control).
final clockProvider =
    NotifierProvider<ClockNotifier, ClockSnapshot?>(ClockNotifier.new);

class ClockNotifier extends Notifier<ClockSnapshot?> {
  Timer? _timer;
  final Stopwatch _sw = Stopwatch();

  @override
  ClockSnapshot? build() {
    final tc = ref.watch(selectedTimeControlProvider);
    ref.onDispose(() {
      _timer?.cancel();
      _sw.stop();
    });
    if (tc.isInfinite) return null;

    final snap = ref.read(gameControllerProvider.notifier).clockSnapshotNow();
    _sw
      ..reset()
      ..start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _onTick());
    return snap;
  }

  void _onTick() {
    final ms = _sw.elapsedMilliseconds;
    _sw
      ..reset()
      ..start();
    final snap = ref.read(gameControllerProvider.notifier).tickClock(ms);
    state = snap;
    if (snap.over) _timer?.cancel();
  }

  /// Charge the moving side's accrued time at the move instant and reset the
  /// stopwatch, so post-move time isn't mis-charged to the opponent. Called by
  /// the game controller immediately BEFORE applying a move.
  void flushElapsed() {
    if (_timer == null) return;
    final ms = _sw.elapsedMilliseconds;
    _sw
      ..reset()
      ..start();
    state = ref.read(gameControllerProvider.notifier).tickClock(ms);
  }

  /// Push the current authoritative clock snapshot immediately (so the running
  /// highlight + Fischer increment update without waiting for the next tick).
  void refreshSnapshot() {
    if (_timer == null) return;
    state = ref.read(gameControllerProvider.notifier).clockSnapshotNow();
  }

  /// Discard accrued time and resync (used on undo).
  void resetAndRefresh() {
    if (_timer == null) return;
    _sw
      ..reset()
      ..start();
    state = ref.read(gameControllerProvider.notifier).clockSnapshotNow();
  }
}
