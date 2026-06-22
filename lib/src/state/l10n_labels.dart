import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/rust/api/game.dart';

/// All supported variants.
const playableVariants = <GameVariant>[
  GameVariant.standard,
  GameVariant.threeCheck,
  GameVariant.kingOfTheHill,
  GameVariant.chess960,
  GameVariant.atomic,
  GameVariant.crazyhouse,
  GameVariant.fogOfWar,
];

/// Stable wire code for a variant (matches the Rust `variant_from_code`), used
/// in the LAN Start message.
String variantCode(GameVariant v) => switch (v) {
      GameVariant.standard => 'standard',
      GameVariant.threeCheck => 'three_check',
      GameVariant.kingOfTheHill => 'king_of_the_hill',
      GameVariant.chess960 => 'chess960',
      GameVariant.atomic => 'atomic',
      GameVariant.crazyhouse => 'crazyhouse',
      GameVariant.bughouse => 'bughouse',
      GameVariant.fogOfWar => 'fog_of_war',
    };

GameVariant variantFromCode(String s) => switch (s) {
      'three_check' => GameVariant.threeCheck,
      'king_of_the_hill' => GameVariant.kingOfTheHill,
      'chess960' => GameVariant.chess960,
      'atomic' => GameVariant.atomic,
      'crazyhouse' => GameVariant.crazyhouse,
      'bughouse' => GameVariant.bughouse,
      'fog_of_war' => GameVariant.fogOfWar,
      _ => GameVariant.standard,
    };

/// Localised variant name.
String localizedVariant(AppLocalizations t, GameVariant v) => switch (v) {
      GameVariant.standard => t.vStandard,
      GameVariant.threeCheck => t.vThreeCheck,
      GameVariant.kingOfTheHill => t.vKingOfTheHill,
      GameVariant.chess960 => t.vChess960,
      GameVariant.atomic => t.vAtomic,
      GameVariant.crazyhouse => t.vCrazyhouse,
      GameVariant.bughouse => t.menuBughouse,
      GameVariant.fogOfWar => t.vFogOfWar,
    };

/// Localised label for a difficulty preset name (the preset list itself stays
/// in English internally; this maps it for display).
String localizedDifficulty(AppLocalizations t, String name) => switch (name) {
      'Beginner' => t.diffBeginner,
      'Easy' => t.diffEasy,
      'Medium' => t.diffMedium,
      'Hard' => t.diffHard,
      'Expert' => t.diffExpert,
      'Custom' => t.custom,
      _ => name,
    };

/// Localised label for a time-control preset ("Infinite" is translated; the
/// numeric "base+inc" labels stay as-is).
String localizedTc(AppLocalizations t, String label) =>
    label == 'Infinite' ? t.tcInfinite : label;

/// Stable codes for non-board game results (resign/draw/disconnect/desync). The
/// controllers store the code (no UI context) and the banner localises it.
class LanResultCode {
  static const youResigned = 'youResigned';
  static const opponentResigned = 'opponentResigned';
  static const drawAgreed = 'drawAgreed';
  static const opponentDisconnected = 'opponentDisconnected';
  static const boardDesync = 'boardDesync';
}

/// Localise a result code; unknown values (e.g. a custom disconnect message
/// sent by the peer) are shown verbatim.
String localizeLanResult(AppLocalizations t, String code) => switch (code) {
      LanResultCode.youResigned => t.youResigned,
      LanResultCode.opponentResigned => t.opponentResigned,
      LanResultCode.drawAgreed => t.drawAgreed,
      LanResultCode.opponentDisconnected => t.opponentDisconnected,
      LanResultCode.boardDesync => t.boardDesync,
      _ => code,
    };
