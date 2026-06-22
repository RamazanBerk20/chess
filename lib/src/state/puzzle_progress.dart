import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persisted puzzle progress: which puzzles are solved, where the user left off,
/// and their best solve streak.
class PuzzleProgress {
  final Set<String> solvedIds;
  final Set<String> attemptedIds;
  final int currentIndex;
  final int bestStreak;

  const PuzzleProgress({
    this.solvedIds = const {},
    this.attemptedIds = const {},
    this.currentIndex = 0,
    this.bestStreak = 0,
  });

  PuzzleProgress copyWith({
    Set<String>? solvedIds,
    Set<String>? attemptedIds,
    int? currentIndex,
    int? bestStreak,
  }) =>
      PuzzleProgress(
        solvedIds: solvedIds ?? this.solvedIds,
        attemptedIds: attemptedIds ?? this.attemptedIds,
        currentIndex: currentIndex ?? this.currentIndex,
        bestStreak: bestStreak ?? this.bestStreak,
      );

  Map<String, dynamic> toJson() => {
        'solved': solvedIds.toList(),
        'attempted': attemptedIds.toList(),
        'currentIndex': currentIndex,
        'bestStreak': bestStreak,
      };

  factory PuzzleProgress.fromJson(Map<String, dynamic> j) => PuzzleProgress(
        solvedIds: (j['solved'] as List? ?? []).cast<String>().toSet(),
        attemptedIds: (j['attempted'] as List? ?? []).cast<String>().toSet(),
        currentIndex: j['currentIndex'] as int? ?? 0,
        bestStreak: j['bestStreak'] as int? ?? 0,
      );
}

Future<File> _progressFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/puzzle_progress.json');
}

Future<PuzzleProgress> loadPuzzleProgress() async {
  try {
    final f = await _progressFile();
    if (!await f.exists()) return const PuzzleProgress();
    final j = json.decode(await f.readAsString()) as Map<String, dynamic>;
    return PuzzleProgress.fromJson(j);
  } catch (_) {
    return const PuzzleProgress();
  }
}

Future<void> savePuzzleProgress(PuzzleProgress p) async {
  try {
    final f = await _progressFile();
    await f.writeAsString(json.encode(p.toJson()));
  } catch (_) {
    // Best-effort persistence; ignore write failures.
  }
}
