import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import 'package:chess/src/rust/api/game.dart';
import 'package:chess/src/widgets/pieces.dart';

/// Display row/column (0 = top/left) for a board square, honouring flip.
(int, int) squareToRowCol(int sq, bool flipped) {
  final rank = sq ~/ 8, file = sq % 8;
  return flipped ? (rank, 7 - file) : (7 - rank, file);
}

int rowColToSquare(int row, int col, bool flipped) {
  final rank = flipped ? row : 7 - row;
  final file = flipped ? 7 - col : col;
  return rank * 8 + file;
}

/// Square index (a1=0) for a UCI square like "e4". Returns null if malformed.
int? uciSquare(String s) {
  if (s.length < 2) return null;
  final file = s.codeUnitAt(0) - 0x61; // 'a'
  final rank = s.codeUnitAt(1) - 0x31; // '1'
  if (file < 0 || file > 7 || rank < 0 || rank > 7) return null;
  return rank * 8 + file;
}

/// The board after the queued premoves are applied as raw relocations, so a
/// premove chain is rendered with each piece on its post-premove square.
List<SquarePiece?> _previewBoard(
    List<SquarePiece?> board, List<(int, int)> premoves) {
  if (premoves.isEmpty) return board;
  final b = List<SquarePiece?>.of(board);
  for (final (f, t) in premoves) {
    b[t] = b[f];
    b[f] = null;
  }
  return b;
}

/// An engine best-move arrow drawn on the analysis board (from → to squares).
class BestArrow {
  final int from;
  final int to;
  final Color color;
  const BestArrow({required this.from, required this.to, required this.color});

  @override
  bool operator ==(Object other) =>
      other is BestArrow &&
      from == other.from &&
      to == other.to &&
      color == other.color;

  @override
  int get hashCode => Object.hash(from, to, color);
}

/// A move-quality badge (symbol in a coloured disc) pinned to the top-right of
/// a square's piece — analysis board only.
class MoveBadge {
  final int square;
  final String symbol;
  final Color color;
  const MoveBadge(
      {required this.square, required this.symbol, required this.color});

  @override
  bool operator ==(Object other) =>
      other is MoveBadge &&
      square == other.square &&
      symbol == other.symbol &&
      color == other.color;

  @override
  int get hashCode => Object.hash(square, symbol, color);
}

/// Presentational chess board: renders a [GameView] with highlights and routes
/// tap/drag back via callbacks. Reused by the game and puzzle screens.
class BoardWidget extends StatelessWidget {
  final GameView view;
  final bool flipped;
  final int? selected;
  final Set<int> targets;
  final bool animate;
  final List<(int, int)> premoves;
  final int? premoveFrom;
  final Set<int> premoveTargets;
  final Color light;
  final Color dark;
  final bool showHints;
  final int animMs;

  /// Analysis overlays: per-square tint colours (e.g. classification colour on
  /// the played move), an optional engine best-move arrow, and an optional
  /// move-quality badge. Empty/absent for the game and puzzle screens, so their
  /// behaviour is unchanged.
  final Map<int, Color> tints;
  final BestArrow? arrow;
  final MoveBadge? badge;

  /// Face-to-face table mode: rotate the pieces sitting at the top of the board
  /// 180° so the opponent across the table sees them upright.
  final bool faceToFace;

  /// Fog of War: the set of squares the viewer can see. Squares NOT in the set
  /// are hidden (piece concealed, dark overlay). Null = no fog.
  final Set<int>? fogMask;
  final void Function(int sq) onTap;
  final void Function(int from, int to) onDrop;

  const BoardWidget({
    super.key,
    required this.view,
    required this.flipped,
    required this.onTap,
    required this.onDrop,
    this.selected,
    this.targets = const {},
    this.animate = false,
    this.premoves = const [],
    this.premoveFrom,
    this.premoveTargets = const {},
    this.light = const Color(0xFFEEEED2),
    this.dark = const Color(0xFF769656),
    this.showHints = true,
    this.animMs = 170,
    this.tints = const {},
    this.arrow,
    this.badge,
    this.faceToFace = false,
    this.fogMask,
  });

  @override
  Widget build(BuildContext context) {
    // King square to flag when in check (no check concept under Fog of War).
    int? checkSquare;
    if (view.inCheck && fogMask == null) {
      for (int sq = 0; sq < 64; sq++) {
        final p = view.board[sq];
        if (p != null &&
            p.kind == PieceKind.king &&
            p.color == view.sideToMove) {
          checkSquare = sq;
          break;
        }
      }
    }

    // Hide legal-move dots if the setting is off (still keep selection).
    final shownTargets = showHints ? targets : const <int>{};

    // A target is a capture if it holds an enemy piece, OR a pawn moving
    // diagonally onto an empty square (en passant) — both get the capture ring.
    final sel = selected;
    final selPiece = sel != null ? view.board[sel] : null;
    final captureTargets = <int>{};
    for (final t in shownTargets) {
      if (view.board[t] != null) {
        captureTargets.add(t);
      } else if (selPiece?.kind == PieceKind.pawn &&
          sel != null &&
          (t % 8) != (sel % 8)) {
        captureTargets.add(t);
      }
    }

    final premoveSquares = <int>{
      for (final (f, t) in premoves) ...[f, t],
      ?premoveFrom,
    };
    // Render pieces in their post-premove squares so a queued chain is visible.
    final renderBoard = _previewBoard(view.board, premoves);

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boardSize = constraints.biggest.shortestSide;
          final cell = boardSize / 8;
          return SizedBox(
            width: boardSize,
            height: boardSize,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BoardPainter(
                      flipped: flipped,
                      selected: selected,
                      targets: shownTargets,
                      captureTargets: captureTargets,
                      lastFrom: view.lastFrom,
                      lastTo: view.lastTo,
                      checkSquare: checkSquare,
                      premoveSquares: premoveSquares,
                      premoveTargets: premoveTargets,
                      light: light,
                      dark: dark,
                      tints: tints,
                      arrow: arrow,
                      fogMask: fogMask,
                    ),
                  ),
                ),
                // Interactive grid (transparent) with pieces on top.
                Column(
                  children: List.generate(8, (row) {
                    return Row(
                      children: List.generate(8, (col) {
                        final sq = rowColToSquare(row, col, flipped);
                        // The color whose pieces sit along the top edge.
                        final topColor =
                            flipped ? PieceColor.white : PieceColor.black;
                        // Fog of War: conceal pieces on unseen squares.
                        final fogged =
                            fogMask != null && !fogMask!.contains(sq);
                        final piece = fogged ? null : renderBoard[sq];
                        final upsideDown = faceToFace &&
                            piece != null &&
                            piece.color == topColor;
                        return _Cell(
                          square: sq,
                          size: cell,
                          piece: piece,
                          flipped: flipped,
                          upsideDown: upsideDown,
                          isLastTo: view.lastTo == sq,
                          lastFrom: view.lastFrom,
                          moveSerial: view.sanMoves.length,
                          animate: animate,
                          animMs: animMs,
                          onTap: () => onTap(sq),
                          onDrop: (from) => onDrop(from, sq),
                        );
                      }),
                    );
                  }),
                ),
                if (badge != null) _badge(cell),
                if (animate && view.lastExplosion && view.lastTo != null)
                  _explosion(view.lastTo!, cell),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Atomic blast effect centred on the explosion square (3×3 area).
  Widget _explosion(int sq, double cell) {
    final (r, c) = squareToRowCol(sq, flipped);
    final size = cell * 3;
    return Positioned(
      left: (c - 1) * cell,
      top: (r - 1) * cell,
      width: size,
      height: size,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey('boom-${view.sanMoves.length}'),
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: animMs * 3),
          curve: Curves.easeOut,
          builder: (_, t, _) =>
              CustomPaint(painter: _ExplosionPainter(t), size: Size(size, size)),
        ),
      ),
    );
  }

  /// Move-quality badge pinned to a top corner of its square's piece, chosen so
  /// it never spills off the board (top-left on the right two files, else
  /// top-right) and clamped inside the board as a final guard.
  Widget _badge(double cell) {
    final (r, c) = squareToRowCol(badge!.square, flipped);
    final sz = cell * 0.46;
    final boardSize = cell * 8;
    final onRight = c >= 6;
    final left = (onRight ? c * cell - sz * 0.28 : c * cell + cell - sz * 0.72)
        .clamp(0.0, boardSize - sz);
    final top = (r * cell - sz * 0.22).clamp(0.0, boardSize - sz);
    return Positioned(
      left: left,
      top: top,
      width: sz,
      height: sz,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: badge!.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.4),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 2)],
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(sz * 0.16),
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(
                badge!.symbol,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final int square;
  final double size;
  final SquarePiece? piece;
  final bool flipped;
  final bool upsideDown;
  final bool isLastTo;
  final int? lastFrom;
  final int moveSerial;
  final bool animate;
  final int animMs;
  final VoidCallback onTap;
  final void Function(int from) onDrop;

  const _Cell({
    required this.square,
    required this.size,
    required this.piece,
    required this.flipped,
    required this.upsideDown,
    required this.isLastTo,
    required this.lastFrom,
    required this.moveSerial,
    required this.animate,
    required this.animMs,
    required this.onTap,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    Widget? child;
    if (piece != null) {
      Widget glyph = PieceGlyph(piece: piece!, size: size, upsideDown: upsideDown);

      // Slide the just-moved piece in from its origin square (not on undo).
      if (animate && isLastTo && lastFrom != null) {
        final (fr, fc) = squareToRowCol(lastFrom!, flipped);
        final (tr, tc) = squareToRowCol(square, flipped);
        final dx = (fc - tc) * size;
        final dy = (fr - tr) * size;
        glyph = TweenAnimationBuilder<double>(
          key: ValueKey('slide-$moveSerial-$square'),
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: animMs),
          curve: Curves.easeOut,
          builder: (_, t, c) => Transform.translate(
            offset: Offset(dx * (1 - t), dy * (1 - t)),
            child: c,
          ),
          child: glyph,
        );
      }

      child = Draggable<int>(
        data: square,
        feedback: Material(
          color: Colors.transparent,
          child: PieceGlyph(
              piece: piece!, size: size * 1.1, upsideDown: upsideDown),
        ),
        childWhenDragging: const SizedBox.shrink(),
        child: glyph,
      );
    }

    return Semantics(
      label: _semanticLabel(),
      button: true,
      container: true,
      child: DragTarget<int>(
        onAcceptWithDetails: (d) => onDrop(d.data),
        builder: (context, candidate, rejected) {
          return GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(child: child),
            ),
          );
        },
      ),
    );
  }

  /// Screen-reader label: square name plus the piece on it (e.g. "e4, white
  /// pawn"), so the board is navigable with TalkBack/VoiceOver.
  String _semanticLabel() {
    final file = String.fromCharCode(97 + square % 8);
    final rank = square ~/ 8 + 1;
    final p = piece;
    if (p == null) return '$file$rank';
    final color = p.color == PieceColor.white ? 'white' : 'black';
    return '$file$rank, $color ${p.kind.name}';
  }
}

class _BoardPainter extends CustomPainter {
  final bool flipped;
  final int? selected;
  final Set<int> targets;
  final Set<int> captureTargets;
  final int? lastFrom;
  final int? lastTo;
  final int? checkSquare;
  final Set<int> premoveSquares;
  final Set<int> premoveTargets;
  final Color light;
  final Color dark;
  final Map<int, Color> tints;
  final BestArrow? arrow;
  final Set<int>? fogMask;

  static const _lastMove = Color(0x99F6F669);
  static const _selectedTint = Color(0x9986C44E);
  static const _hint = Color(0x55303030);
  static const _premove = Color(0x99E08A2B); // orange
  static const _fog = Color(0xCC101418); // dark veil over unseen squares

  _BoardPainter({
    required this.flipped,
    required this.selected,
    required this.targets,
    required this.captureTargets,
    required this.lastFrom,
    required this.lastTo,
    required this.checkSquare,
    required this.premoveSquares,
    required this.premoveTargets,
    required this.light,
    required this.dark,
    required this.tints,
    required this.arrow,
    required this.fogMask,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 8;
    final paint = Paint();
    final labelStyleDark = TextStyle(
      color: dark,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );
    final labelStyleLight = TextStyle(
      color: light,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final sq = rowColToSquare(row, col, flipped);
        final file = sq % 8, rank = sq ~/ 8;
        final isLight = (file + rank) % 2 == 1;
        final rect = Rect.fromLTWH(col * cell, row * cell, cell, cell);

        paint.color = isLight ? light : dark;
        canvas.drawRect(rect, paint);

        // Fog of War: veil unseen squares and skip every highlight/label on them
        // (so they leak no last-move / check / hint information).
        if (fogMask != null && !fogMask!.contains(sq)) {
          paint.color = _fog;
          canvas.drawRect(rect, paint);
          continue;
        }

        if (sq == lastFrom || sq == lastTo) {
          paint.color = _lastMove;
          canvas.drawRect(rect, paint);
        }
        // Analysis classification tint on the played move's squares (drawn over
        // the last-move tint so the classification colour wins).
        final tint = tints[sq];
        if (tint != null) {
          paint.color = tint;
          canvas.drawRect(rect, paint);
        }
        if (sq == selected) {
          paint.color = _selectedTint;
          canvas.drawRect(rect, paint);
        }
        if (premoveSquares.contains(sq)) {
          paint.color = _premove;
          canvas.drawRect(rect, paint);
        }
        if (sq == checkSquare) {
          paint.color = const Color(0x88FF3030);
          canvas.drawCircle(rect.center, cell * 0.48, paint);
        }
        if (premoveTargets.contains(sq)) {
          paint.color = _premove;
          canvas.drawCircle(rect.center, cell * 0.16, paint);
        }
        if (targets.contains(sq)) {
          paint.color = _hint;
          if (captureTargets.contains(sq)) {
            paint.style = PaintingStyle.stroke;
            paint.strokeWidth = cell * 0.08;
            canvas.drawCircle(rect.center, cell * 0.42, paint);
            paint.style = PaintingStyle.fill;
          } else {
            canvas.drawCircle(rect.center, cell * 0.16, paint);
          }
        }

        // Edge coordinate labels.
        if (col == 0) {
          _label(canvas, '${rank + 1}', Offset(rect.left + 2, rect.top + 1),
              isLight ? labelStyleDark : labelStyleLight);
        }
        if (row == 7) {
          final fileChar = String.fromCharCode('a'.codeUnitAt(0) + file);
          _label(
              canvas,
              fileChar,
              Offset(rect.right - 9, rect.bottom - 12),
              isLight ? labelStyleDark : labelStyleLight);
        }
      }
    }

    final a = arrow;
    if (a != null) {
      _drawArrow(canvas, cell, a);
    }
  }

  /// Draw the engine best-move arrow from → to (analysis board only).
  void _drawArrow(Canvas canvas, double cell, BestArrow a) {
    Offset center(int sq) {
      final (r, c) = squareToRowCol(sq, flipped);
      return Offset((c + 0.5) * cell, (r + 0.5) * cell);
    }

    final from = center(a.from);
    final to = center(a.to);
    final dir = to - from;
    final len = dir.distance;
    if (len < 1) return;
    final unit = dir / len;
    final head = cell * 0.34;
    final tip = to - unit * (cell * 0.08);
    final base = tip - unit * head;

    canvas.drawLine(
      from,
      base,
      Paint()
        ..color = a.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.15
        ..strokeCap = StrokeCap.round,
    );
    final perp = Offset(-unit.dy, unit.dx) * (head * 0.5);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx + perp.dx, base.dy + perp.dy)
      ..lineTo(base.dx - perp.dx, base.dy - perp.dy)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..color = a.color
          ..style = PaintingStyle.fill);
  }

  void _label(Canvas canvas, String text, Offset at, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) {
    return flipped != old.flipped ||
        selected != old.selected ||
        targets != old.targets ||
        lastFrom != old.lastFrom ||
        lastTo != old.lastTo ||
        checkSquare != old.checkSquare ||
        premoveSquares != old.premoveSquares ||
        premoveTargets != old.premoveTargets ||
        light != old.light ||
        dark != old.dark ||
        tints != old.tints ||
        arrow != old.arrow ||
        !setEquals(fogMask, old.fogMask);
  }
}

/// An expanding fiery burst for an Atomic explosion. `t` runs 0 → 1.
class _ExplosionPainter extends CustomPainter {
  final double t;
  _ExplosionPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final fade = (1 - t).clamp(0.0, 1.0);

    // Bright flash core, expanding and fading.
    final coreR = maxR * (0.45 + 0.55 * t);
    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromRGBO(255, 238, 150, fade * 0.95),
            Color.fromRGBO(255, 130, 35, fade * 0.8),
            const Color(0x00FF6600),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: coreR)),
    );

    // Expanding shock ring.
    canvas.drawCircle(
      c,
      maxR * (0.3 + 0.7 * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (maxR * 0.14 * fade).clamp(0.5, maxR)
        ..color = Color.fromRGBO(255, 190, 70, fade * 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _ExplosionPainter old) => old.t != t;
}
