import 'dart:math';

import 'package:flutter/material.dart';

import 'package:chess/src/state/analysis_provider.dart';
import 'package:chess/src/widgets/move_class.dart';

/// A compact eval graph over the whole game (White advantage, win%-mapped).
/// White's share fills from the bottom; blunders/mistakes/misses are dotted in
/// their classification colour; the current ply is marked. Tap to seek.
class EvalGraph extends StatelessWidget {
  final List<AnalysisMove> moves;
  final int viewPly;
  final void Function(int ply) onSeek;
  final double height;
  final bool colorblind;

  const EvalGraph({
    super.key,
    required this.moves,
    required this.viewPly,
    required this.onSeek,
    this.height = 56,
    this.colorblind = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return GestureDetector(
            onTapDown: (d) {
              final n = moves.length;
              if (n == 0) return;
              final ply = (d.localPosition.dx / w * n).round().clamp(0, n);
              onSeek(ply);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CustomPaint(
                size: Size(w, height),
                painter: _EvalGraphPainter(
                    moves: moves, viewPly: viewPly, colorblind: colorblind),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EvalGraphPainter extends CustomPainter {
  final List<AnalysisMove> moves;
  final int viewPly;
  final bool colorblind;
  _EvalGraphPainter(
      {required this.moves, required this.viewPly, required this.colorblind});

  double _frac(int cp, int mateIn) {
    if (mateIn != 0) return mateIn > 0 ? 1.0 : 0.0;
    return 1.0 / (1.0 + exp(-0.00368208 * cp));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF2B2B2B));
    final n = moves.length;
    if (n == 0) return;

    // Sample 0 is the start position (eval before the first move); samples
    // 1..n are the evals after each played ply.
    final fracs = <double>[
      _frac(moves[0].evalBeforeCp, moves[0].mateBeforeIn),
      for (final m in moves) _frac(m.evalCp, m.mateIn),
    ];
    Offset pt(int i) => Offset((i / n) * w, (1 - fracs[i]) * h);

    // White area: fill from the bottom up to the eval line.
    final area = Path()..moveTo(0, h);
    for (var i = 0; i < fracs.length; i++) {
      final p = pt(i);
      area.lineTo(p.dx, p.dy);
    }
    area
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(area, Paint()..color = const Color(0xFFE8E8E8));

    // 50% midline.
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2),
        Paint()..color = const Color(0x44000000)..strokeWidth = 1);

    // Eval line.
    final line = Path();
    for (var i = 0; i < fracs.length; i++) {
      final p = pt(i);
      if (i == 0) {
        line.moveTo(p.dx, p.dy);
      } else {
        line.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
        line,
        Paint()
          ..color = const Color(0xFF6E6E6E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    // Flag the costly moves.
    for (var i = 0; i < moves.length; i++) {
      final cls = moves[i].classification;
      if (cls == 'blunder' || cls == 'mistake' || cls == 'miss') {
        canvas.drawCircle(pt(i + 1), 2.6,
            Paint()..color = classStyle(cls, colorblind: colorblind).color);
      }
    }

    // Current-ply marker.
    final mx = (viewPly / n).clamp(0.0, 1.0) * w;
    canvas.drawLine(Offset(mx, 0), Offset(mx, h),
        Paint()..color = const Color(0xCC1E88E5)..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _EvalGraphPainter old) =>
      old.viewPly != viewPly ||
      old.moves != moves ||
      old.colorblind != colorblind;
}
