import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/src/rust/api/game.dart';
import 'package:chess/src/state/difficulty.dart';

/// Human-vs-human (same device), vs the AI, or a LAN game.
class GameMode {
  final bool vsAi;
  final PieceColor? aiColor;
  final Difficulty difficulty;
  final bool lan;
  final PieceColor? lanMyColor;

  const GameMode({
    this.vsAi = false,
    this.aiColor,
    this.difficulty = Difficulty.medium,
    this.lan = false,
    this.lanMyColor,
  });
}

final gameModeProvider =
    NotifierProvider<GameModeController, GameMode>(GameModeController.new);

class GameModeController extends Notifier<GameMode> {
  @override
  GameMode build() => const GameMode();

  void setTwoPlayer() => state = const GameMode();

  void setVsAi(PieceColor aiColor, Difficulty difficulty) =>
      state = GameMode(vsAi: true, aiColor: aiColor, difficulty: difficulty);

  void setLan(PieceColor myColor) =>
      state = GameMode(lan: true, lanMyColor: myColor);
}
