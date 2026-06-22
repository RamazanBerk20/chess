import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/src/rust/api/game.dart';
import 'package:chess/src/state/clock_provider.dart';

/// Format remaining milliseconds: tenths under 20s, else M:SS.
String formatClock(int ms) {
  if (ms < 0) ms = 0;
  if (ms < 20000) {
    // Floor to tenths so 19999ms reads "19.9", not a rounded "20.0".
    final tenths = ms ~/ 100;
    return '${tenths ~/ 10}.${tenths % 10}';
  }
  final totalSec = ms ~/ 1000;
  final m = totalSec ~/ 60;
  final s = totalSec % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// A single player's clock chip. Renders nothing in Infinite time control.
class PlayerClock extends ConsumerWidget {
  final PieceColor color;
  const PlayerClock({super.key, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(clockProvider);
    if (snap == null || snap.infinite) return const SizedBox.shrink();
    final ms = color == PieceColor.white ? snap.whiteMs : snap.blackMs;
    final running = !snap.over && snap.running == color;
    final low = ms < 10000;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: running ? Colors.amber.shade800 : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        formatClock(ms),
        style: TextStyle(
          color: low ? Colors.red.shade200 : Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// A clock chip fed an explicit [ClockSnapshot] — for screens that run more than
/// one game at once (Bughouse) and can't use the global clockProvider.
class ClockText extends StatelessWidget {
  final ClockSnapshot snap;
  final PieceColor color;
  const ClockText({super.key, required this.snap, required this.color});

  @override
  Widget build(BuildContext context) {
    if (snap.infinite) return const SizedBox.shrink();
    final ms = color == PieceColor.white ? snap.whiteMs : snap.blackMs;
    final running = !snap.over && snap.running == color;
    final low = ms < 10000;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: running ? Colors.amber.shade800 : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        formatClock(ms),
        style: TextStyle(
          color: low ? Colors.red.shade200 : Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
