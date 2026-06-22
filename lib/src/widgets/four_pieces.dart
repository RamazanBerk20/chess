import 'package:flutter/material.dart';

import 'package:chess/src/rust/api/four.dart';

const _glyphs = {
  FourPieceKind.king: '♚',
  FourPieceKind.queen: '♛',
  FourPieceKind.rook: '♜',
  FourPieceKind.bishop: '♝',
  FourPieceKind.knight: '♞',
  FourPieceKind.pawn: '♟',
};

/// Army fill colours.
const fourColors = {
  FourPlayer.red: Color(0xFFD23B3B),
  FourPlayer.blue: Color(0xFF3F6FD8),
  FourPlayer.yellow: Color(0xFFD7B72E),
  FourPlayer.green: Color(0xFF3DA84E),
};

/// A 4-player piece: a filled glyph in the army's colour with a dark outline so
/// all four colours read on light and dark squares.
class FourPieceGlyph extends StatelessWidget {
  final FourPlayer player;
  final FourPieceKind kind;
  final double size;
  final bool dead;

  const FourPieceGlyph({
    super.key,
    required this.player,
    required this.kind,
    required this.size,
    this.dead = false,
  });

  @override
  Widget build(BuildContext context) {
    final fill = dead ? const Color(0xFF8A8A8A) : (fourColors[player] ?? Colors.white);
    final glyph = _glyphs[kind]!;
    final fontSize = size * 0.82;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            glyph,
            style: TextStyle(
              fontFamily: 'ChessGlyphs',
              fontSize: fontSize,
              height: 1.0,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = size * 0.05
                ..color = Colors.black.withValues(alpha: 0.85),
            ),
          ),
          Text(
            glyph,
            style: TextStyle(
              fontFamily: 'ChessGlyphs',
              fontSize: fontSize,
              height: 1.0,
              color: fill,
            ),
          ),
        ],
      ),
    );
  }
}
