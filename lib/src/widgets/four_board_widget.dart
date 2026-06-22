import 'package:flutter/material.dart';

import 'package:chess/src/rust/api/four.dart';
import 'package:chess/src/widgets/four_pieces.dart';

/// The 14×14 four-player cross board. Cell index = row*14 + col (row 0 = the
/// bottom edge, Red's side); invalid corner cells render as holes.
class FourBoardWidget extends StatelessWidget {
  final FourView view;
  final int? selected;
  final Set<int> targets;
  final List<(int, int)> premoves;
  final int? premoveFrom;
  final Set<int> premoveTargets;
  final void Function(int sq) onTap;
  final void Function(int from, int to) onDrop;

  const FourBoardWidget({
    super.key,
    required this.view,
    required this.selected,
    required this.targets,
    this.premoves = const [],
    this.premoveFrom,
    this.premoveTargets = const {},
    required this.onTap,
    required this.onDrop,
  });

  static const _light = Color(0xFFEDEAD2);
  static const _dark = Color(0xFF6E8C57);
  static const _premoveTint = Color(0x99E08A2B);

  /// Board after the queued premoves (raw relocations) so a chain renders.
  List<FourSquarePiece?> _previewBoard() {
    if (premoves.isEmpty) return view.board;
    final out = List<FourSquarePiece?>.of(view.board);
    for (final (f, t) in premoves) {
      out[t] = out[f];
      out[f] = null;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final dead = <FourPlayer>{
      for (final p in view.players)
        if (p.status != FourPlayerStatus.active) p.player,
    };
    final board = _previewBoard();
    final premoveSquares = <int>{
      for (final (f, t) in premoves) ...[f, t],
      ?premoveFrom,
    };
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, c) {
          final cell = c.biggest.shortestSide / 14;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int dr = 0; dr < 14; dr++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int col = 0; col < 14; col++)
                      _cell(13 - dr, col, cell, dead, board, premoveSquares),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _cell(int boardRow, int col, double cell, Set<FourPlayer> dead,
      List<FourSquarePiece?> board, Set<int> premoveSquares) {
    final sq = boardRow * 14 + col;
    if (!view.valid[sq]) {
      return SizedBox(width: cell, height: cell); // cut corner → hole
    }
    final piece = board[sq];
    final isLight = (col + boardRow) % 2 == 0;
    final isTarget = targets.contains(sq);
    final isPremoveTarget = premoveTargets.contains(sq);

    final content = Stack(
      fit: StackFit.expand,
      children: [
        Container(color: isLight ? _light : _dark),
        if (view.lastFrom == sq || view.lastTo == sq)
          Container(color: const Color(0x66F6F669)),
        if (selected == sq) Container(color: const Color(0x8086C44E)),
        if (premoveSquares.contains(sq)) Container(color: _premoveTint),
        if (isPremoveTarget)
          Center(
            child: Container(
              width: cell * (piece != null ? 0.92 : 0.32),
              height: cell * (piece != null ? 0.92 : 0.32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: piece != null ? null : _premoveTint,
                border: piece != null
                    ? Border.all(color: _premoveTint, width: cell * 0.08)
                    : null,
              ),
            ),
          ),
        if (isTarget)
          Center(
            child: Container(
              width: cell * (piece != null ? 0.92 : 0.32),
              height: cell * (piece != null ? 0.92 : 0.32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: piece != null ? null : const Color(0x55303030),
                border: piece != null
                    ? Border.all(
                        color: const Color(0x55303030), width: cell * 0.08)
                    : null,
              ),
            ),
          ),
        if (piece != null)
          Center(
            child: FourPieceGlyph(
              player: piece.player,
              kind: piece.kind,
              size: cell,
              dead: dead.contains(piece.player),
            ),
          ),
      ],
    );

    Widget w = GestureDetector(
      onTap: () => onTap(sq),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (d) => onDrop(d.data, sq),
        builder: (_, _, _) => content,
      ),
    );
    if (piece != null) {
      w = Draggable<int>(
        data: sq,
        feedback: FourPieceGlyph(
          player: piece.player,
          kind: piece.kind,
          size: cell,
          dead: dead.contains(piece.player),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: content),
        child: w,
      );
    }
    return SizedBox(width: cell, height: cell, child: w);
  }
}
