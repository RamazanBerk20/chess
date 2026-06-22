import 'package:flutter/material.dart';

import 'package:chess/src/rust/api/game.dart';
import 'package:chess/src/widgets/pieces.dart';

const Map<PieceKind, int> _value = {
  PieceKind.pawn: 1,
  PieceKind.knight: 3,
  PieceKind.bishop: 3,
  PieceKind.rook: 5,
  PieceKind.queen: 9,
  PieceKind.king: 0,
};

/// A row of pieces a side has captured, with the running material advantage.
class CapturedTray extends StatelessWidget {
  /// The color of the player who owns this tray (its captured pieces are the
  /// opponent's, so they are drawn in the opponent's color).
  final PieceColor owner;
  final List<PieceKind> captured;
  final int advantage; // material points ahead (only shown when > 0)

  const CapturedTray({
    super.key,
    required this.owner,
    required this.captured,
    required this.advantage,
  });

  @override
  Widget build(BuildContext context) {
    final oppColor =
        owner == PieceColor.white ? PieceColor.black : PieceColor.white;
    final sorted = [...captured]
      ..sort((a, b) => _value[b]!.compareTo(_value[a]!));
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          for (final k in sorted)
            SizedBox(
              width: 16,
              child: PieceGlyph(
                piece: SquarePiece(color: oppColor, kind: k),
                size: 20,
              ),
            ),
          if (advantage > 0)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('+$advantage',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

/// Material advantage for [a] over [b] given the two captured lists
/// (captured-by-white minus captured-by-black net).
int materialAdvantage(List<PieceKind> mine, List<PieceKind> theirs) {
  int sum(List<PieceKind> l) => l.fold(0, (acc, k) => acc + _value[k]!);
  return sum(mine) - sum(theirs);
}
