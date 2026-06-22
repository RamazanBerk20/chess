import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// A saved game: the move list (UCI) plus a name and timestamp, replayed on
/// resume from the start position.
class SavedGame {
  final String id;
  final String name;
  final List<String> moves;
  final String createdAt;

  const SavedGame({
    required this.id,
    required this.name,
    required this.moves,
    required this.createdAt,
  });

  int get ply => moves.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'moves': moves,
        'createdAt': createdAt,
      };

  factory SavedGame.fromJson(Map<String, dynamic> j) => SavedGame(
        id: j['id'] as String,
        name: j['name'] as String,
        moves: (j['moves'] as List).cast<String>(),
        createdAt: j['createdAt'] as String? ?? '',
      );
}

Future<File> _file() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/saved_games.json');
}

Future<List<SavedGame>> loadSavedGames() async {
  try {
    final f = await _file();
    if (!await f.exists()) return [];
    final list = json.decode(await f.readAsString()) as List;
    return list
        .map((e) => SavedGame.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveSavedGames(List<SavedGame> games) async {
  try {
    final f = await _file();
    await f.writeAsString(json.encode(games.map((g) => g.toJson()).toList()));
  } catch (_) {}
}

final savedGamesProvider =
    AsyncNotifierProvider<SavedGamesController, List<SavedGame>>(
        SavedGamesController.new);

class SavedGamesController extends AsyncNotifier<List<SavedGame>> {
  @override
  Future<List<SavedGame>> build() => loadSavedGames();

  Future<void> add(SavedGame g) async {
    final list = <SavedGame>[...?state.value, g];
    await saveSavedGames(list);
    state = AsyncData(list);
  }

  Future<void> remove(String id) async {
    final list =
        (state.value ?? const <SavedGame>[]).where((g) => g.id != id).toList();
    await saveSavedGames(list);
    state = AsyncData(list);
  }

  Future<void> rename(String id, String name) async {
    final list = (state.value ?? const <SavedGame>[])
        .map((g) => g.id == id
            ? SavedGame(
                id: g.id, name: name, moves: g.moves, createdAt: g.createdAt)
            : g)
        .toList();
    await saveSavedGames(list);
    state = AsyncData(list);
  }
}
