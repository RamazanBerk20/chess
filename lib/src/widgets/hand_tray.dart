import 'package:flutter/material.dart';

import 'package:chess/src/rust/api/game.dart';
import 'package:chess/src/widgets/pieces.dart';

/// Reserve-piece order matching the Rust hand index (Pawn..Queen).
const handKinds = [
  PieceKind.pawn,
  PieceKind.knight,
  PieceKind.bishop,
  PieceKind.rook,
  PieceKind.queen,
];

/// Crazyhouse/Bughouse reserve row: tappable captured pieces available to drop.
class HandTray extends StatelessWidget {
  final PieceColor owner;
  final List<int> counts; // [Pawn, Knight, Bishop, Rook, Queen]
  final bool interactive;
  final int? selected;
  final ValueChanged<int> onTap;
  final bool upsideDown;

  const HandTray({
    super.key,
    required this.owner,
    required this.counts,
    required this.interactive,
    required this.selected,
    required this.onTap,
    this.upsideDown = false,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (var i = 0; i < handKinds.length; i++) {
      final n = i < counts.length ? counts[i] : 0;
      if (n == 0) continue;
      final isSel = interactive && selected == i;
      chips.add(GestureDetector(
        onTap: interactive ? () => onTap(i) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: isSel
                ? Colors.amber.withValues(alpha: 0.55)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PieceGlyph(
                piece: SquarePiece(color: owner, kind: handKinds[i]),
                size: 34,
                upsideDown: upsideDown,
              ),
              if (n > 1)
                Text('×$n',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: chips,
    );
  }
}
