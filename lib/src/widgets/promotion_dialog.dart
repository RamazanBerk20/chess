import 'package:flutter/material.dart';

import 'package:chess/src/rust/api/game.dart';
import 'package:chess/src/widgets/pieces.dart';

/// Ask the user which piece to promote to. Returns null if dismissed.
Future<PieceKind?> showPromotionDialog(
  BuildContext context,
  PieceColor color,
) {
  const choices = [
    PieceKind.queen,
    PieceKind.rook,
    PieceKind.bishop,
    PieceKind.knight,
  ];
  return showDialog<PieceKind>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Promote to'),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final k in choices)
            IconButton(
              iconSize: 48,
              onPressed: () => Navigator.of(context).pop(k),
              icon: PieceGlyph(piece: SquarePiece(color: color, kind: k), size: 44),
            ),
        ],
      ),
    ),
  );
}
