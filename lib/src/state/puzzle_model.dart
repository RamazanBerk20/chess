import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// A bundled puzzle (Lichess CC0). The [fen] is the player-to-move position;
/// [solution] is the line the player must follow (player, opponent, player…).
class Puzzle {
  final String id;
  final String fen;
  final List<String> solution; // UCI moves
  final List<String> themes;
  final int rating;
  final String sideToMove; // 'white' | 'black' — the player's side

  const Puzzle({
    required this.id,
    required this.fen,
    required this.solution,
    required this.themes,
    required this.rating,
    required this.sideToMove,
  });

  factory Puzzle.fromJson(Map<String, dynamic> j) => Puzzle(
        id: j['id'] as String,
        fen: j['fen'] as String,
        solution: (j['solution'] as List).cast<String>(),
        themes: (j['themes'] as List).cast<String>(),
        rating: j['rating'] as int,
        sideToMove: j['side_to_move'] as String,
      );
}

/// Load the bundled 100-puzzle set (ordered easy → hard).
Future<List<Puzzle>> loadPuzzles() async {
  final raw = await rootBundle.loadString('assets/puzzles/puzzles.json');
  final list = json.decode(raw) as List;
  return list
      .map((e) => Puzzle.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}
