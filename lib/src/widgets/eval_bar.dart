import 'dart:math';

import 'package:flutter/material.dart';

/// A vertical evaluation bar. White's share fills from the bottom; the numeric
/// advantage (or mate distance) is printed at the leading edge.
class EvalBar extends StatelessWidget {
  final int evalCp; // White POV
  final int mateIn; // 0 = none; signed plies (White mating > 0)
  final double height;
  final double width;

  /// When true (board flipped, Black at the bottom) White's share fills from
  /// the top instead of the bottom so the bar matches the board orientation.
  final bool flipped;

  const EvalBar({
    super.key,
    required this.evalCp,
    required this.mateIn,
    required this.height,
    this.width = 22,
    this.flipped = false,
  });

  @override
  Widget build(BuildContext context) {
    double whiteFrac;
    String label;
    bool whiteAhead;
    if (mateIn != 0) {
      whiteAhead = mateIn > 0;
      whiteFrac = whiteAhead ? 1.0 : 0.0;
      label = 'M${mateIn.abs()}';
    } else {
      whiteFrac = 1.0 / (1.0 + exp(-0.00368208 * evalCp));
      whiteAhead = evalCp >= 0;
      final pawns = (evalCp.abs() / 100).toStringAsFixed(1);
      label = pawns;
    }
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        // Animate White's share smoothly when the eval changes.
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: whiteFrac.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          builder: (context, frac, _) {
            return Stack(
              children: [
                Container(color: const Color(0xFF2B2B2B)), // black side
                Align(
                  alignment:
                      flipped ? Alignment.topCenter : Alignment.bottomCenter,
                  child: Container(
                    height: (height * frac).clamp(0.0, height),
                    width: width,
                    color: const Color(0xFFE8E8E8), // white side
                  ),
                ),
                // Numeric label at the winning side's end.
                Align(
                  alignment: (whiteAhead != flipped)
                      ? Alignment.bottomCenter
                      : Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: whiteAhead ? Colors.black87 : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
