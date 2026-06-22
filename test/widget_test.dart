import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess/src/rust/api/game.dart';
import 'package:chess/src/widgets/board_widget.dart';
import 'package:chess/src/widgets/captured_tray.dart';
import 'package:chess/src/widgets/clock_widget.dart';
import 'package:chess/src/widgets/move_list.dart';

void main() {
  group('board coordinate mapping', () {
    test('a1/h8 map correctly when not flipped', () {
      expect(squareToRowCol(0, false), (7, 0)); // a1 bottom-left
      expect(squareToRowCol(63, false), (0, 7)); // h8 top-right
      expect(rowColToSquare(7, 0, false), 0);
      expect(rowColToSquare(0, 7, false), 63);
    });

    test('a1/h8 map correctly when flipped', () {
      expect(squareToRowCol(0, true), (0, 7)); // a1 top-right
      expect(squareToRowCol(63, true), (7, 0)); // h8 bottom-left
    });

    test('row/col <-> square round-trips for both orientations', () {
      for (final flipped in [false, true]) {
        for (int sq = 0; sq < 64; sq++) {
          final (r, c) = squareToRowCol(sq, flipped);
          expect(rowColToSquare(r, c, flipped), sq);
        }
      }
    });
  });

  test('materialAdvantage sums piece values', () {
    expect(materialAdvantage([PieceKind.queen], [PieceKind.rook]), 4); // 9 - 5
    expect(materialAdvantage([], []), 0);
  });

  test('formatClock shows M:SS and sub-second under 20s', () {
    expect(formatClock(600000), '10:00');
    expect(formatClock(65000), '1:05');
    expect(formatClock(20000), '0:20');
    expect(formatClock(19999), '19.9'); // floor, not rounded "20.0"
    expect(formatClock(9999), '9.9');
    expect(formatClock(1500), '1.5');
    expect(formatClock(0), '0.0');
    expect(formatClock(-5), '0.0');
  });

  testWidgets('MoveList renders numbered SAN pairs', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MoveList(sanMoves: ['e4', 'e5', 'Nf3'])),
    ));
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('e4'), findsOneWidget);
    expect(find.text('e5'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    expect(find.text('Nf3'), findsOneWidget);
  });
}
