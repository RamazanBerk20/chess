import 'package:flutter/material.dart';

import 'package:chess/src/rust/api/game.dart';

/// Solid (filled) Unicode glyphs for every piece kind. We use the filled set for
/// both colors and tint them, so White pieces stay visible on light squares.
const Map<PieceKind, String> _glyphs = {
  PieceKind.king: '♚',
  PieceKind.queen: '♛',
  PieceKind.rook: '♜',
  PieceKind.bishop: '♝',
  PieceKind.knight: '♞',
  PieceKind.pawn: '♟',
};

String pieceGlyph(PieceKind kind) => _glyphs[kind]!;

/// A single rendered piece glyph, sized to fill `size`, with an outline so White
/// reads clearly on light squares and Black on dark squares.
class PieceGlyph extends StatelessWidget {
  final SquarePiece piece;
  final double size;

  /// Render the glyph rotated 180° (face-to-face same-device play, so the player
  /// sitting on the opposite side sees their pieces upright).
  final bool upsideDown;

  const PieceGlyph({
    super.key,
    required this.piece,
    required this.size,
    this.upsideDown = false,
  });

  @override
  Widget build(BuildContext context) {
    final isWhite = piece.color == PieceColor.white;
    final fill = isWhite ? Colors.white : const Color(0xFF1A1A1A);
    // Full-opacity contrasting outline so pieces read on board squares AND on
    // the dark app surface (promotion dialog, captured tray).
    final outline = isWhite ? Colors.black : Colors.white;
    final glyph = pieceGlyph(piece.kind);
    final fontSize = size * 0.82;

    final box = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outline (stroked text drawn behind the fill).
          Text(
            glyph,
            style: TextStyle(
              fontFamily: 'ChessGlyphs',
              fontSize: fontSize,
              height: 1.0,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = size * 0.04
                ..color = outline,
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

    return upsideDown ? RotatedBox(quarterTurns: 2, child: box) : box;
  }
}
