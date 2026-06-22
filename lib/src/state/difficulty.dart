import 'package:chess/src/rust/api/ai.dart';

/// A difficulty profile mapping to an engine [AiConfigDto]. Weak presets use
/// *principled* weakening (shallow search, top-N random, deliberate blunders,
/// eval noise) rather than a broken engine.
class Difficulty {
  final String name;
  final int maxDepth;
  final int moveTimeMs;
  final int evalNoise;
  final double blunderChance;
  final int topNRandom;
  final int contempt;

  const Difficulty(
    this.name, {
    required this.maxDepth,
    required this.moveTimeMs,
    this.evalNoise = 0,
    this.blunderChance = 0.0,
    this.topNRandom = 1,
    this.contempt = 0,
  });

  AiConfigDto toConfig(int seed) => AiConfigDto(
        maxDepth: maxDepth,
        moveTimeMs: BigInt.from(moveTimeMs),
        evalNoise: evalNoise,
        blunderChance: blunderChance,
        topNRandom: topNRandom,
        contempt: contempt,
        seed: BigInt.from(seed),
      );

  Difficulty copyWith({
    String? name,
    int? maxDepth,
    int? moveTimeMs,
    int? evalNoise,
    double? blunderChance,
    int? topNRandom,
    int? contempt,
  }) =>
      Difficulty(
        name ?? this.name,
        maxDepth: maxDepth ?? this.maxDepth,
        moveTimeMs: moveTimeMs ?? this.moveTimeMs,
        evalNoise: evalNoise ?? this.evalNoise,
        blunderChance: blunderChance ?? this.blunderChance,
        topNRandom: topNRandom ?? this.topNRandom,
        contempt: contempt ?? this.contempt,
      );

  static const beginner = Difficulty('Beginner',
      maxDepth: 2, moveTimeMs: 100, evalNoise: 120, blunderChance: 0.35, topNRandom: 4);
  static const easy = Difficulty('Easy',
      maxDepth: 3, moveTimeMs: 300, evalNoise: 60, blunderChance: 0.15, topNRandom: 3);
  static const medium = Difficulty('Medium',
      maxDepth: 5, moveTimeMs: 800, evalNoise: 20, blunderChance: 0.05, topNRandom: 2);
  static const hard = Difficulty('Hard', maxDepth: 7, moveTimeMs: 1500);
  static const expert = Difficulty('Expert', maxDepth: 10, moveTimeMs: 3000);

  static const presets = <Difficulty>[beginner, easy, medium, hard, expert];
}
