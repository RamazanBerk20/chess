import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('ko'),
    Locale('ru'),
    Locale('tr'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Chess'**
  String get appTitle;

  /// No description provided for @menuSinglePlayer.
  ///
  /// In en, this message translates to:
  /// **'Single Player'**
  String get menuSinglePlayer;

  /// No description provided for @menuTwoPlayers.
  ///
  /// In en, this message translates to:
  /// **'Two Players'**
  String get menuTwoPlayers;

  /// No description provided for @menuLan.
  ///
  /// In en, this message translates to:
  /// **'Play over LAN'**
  String get menuLan;

  /// No description provided for @menuPuzzles.
  ///
  /// In en, this message translates to:
  /// **'Puzzles'**
  String get menuPuzzles;

  /// No description provided for @menuResume.
  ///
  /// In en, this message translates to:
  /// **'Resume Game'**
  String get menuResume;

  /// No description provided for @menuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get menuSettings;

  /// No description provided for @menuPlayFromPosition.
  ///
  /// In en, this message translates to:
  /// **'Play from Position'**
  String get menuPlayFromPosition;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @whiteToMove.
  ///
  /// In en, this message translates to:
  /// **'White to move'**
  String get whiteToMove;

  /// No description provided for @blackToMove.
  ///
  /// In en, this message translates to:
  /// **'Black to move'**
  String get blackToMove;

  /// No description provided for @whiteToMoveCheck.
  ///
  /// In en, this message translates to:
  /// **'White to move — check!'**
  String get whiteToMoveCheck;

  /// No description provided for @blackToMoveCheck.
  ///
  /// In en, this message translates to:
  /// **'Black to move — check!'**
  String get blackToMoveCheck;

  /// No description provided for @checkmateWhiteWins.
  ///
  /// In en, this message translates to:
  /// **'Checkmate — White wins'**
  String get checkmateWhiteWins;

  /// No description provided for @checkmateBlackWins.
  ///
  /// In en, this message translates to:
  /// **'Checkmate — Black wins'**
  String get checkmateBlackWins;

  /// No description provided for @whiteWinsOnTime.
  ///
  /// In en, this message translates to:
  /// **'White wins on time'**
  String get whiteWinsOnTime;

  /// No description provided for @blackWinsOnTime.
  ///
  /// In en, this message translates to:
  /// **'Black wins on time'**
  String get blackWinsOnTime;

  /// No description provided for @drawStalemate.
  ///
  /// In en, this message translates to:
  /// **'Draw — stalemate'**
  String get drawStalemate;

  /// No description provided for @drawFiftyMove.
  ///
  /// In en, this message translates to:
  /// **'Draw — fifty-move rule'**
  String get drawFiftyMove;

  /// No description provided for @drawThreefold.
  ///
  /// In en, this message translates to:
  /// **'Draw — threefold repetition'**
  String get drawThreefold;

  /// No description provided for @drawInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Draw — insufficient material'**
  String get drawInsufficient;

  /// No description provided for @resign.
  ///
  /// In en, this message translates to:
  /// **'Resign'**
  String get resign;

  /// No description provided for @offerDraw.
  ///
  /// In en, this message translates to:
  /// **'Offer draw'**
  String get offerDraw;

  /// No description provided for @drawOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Draw offer'**
  String get drawOfferTitle;

  /// No description provided for @drawOfferBody.
  ///
  /// In en, this message translates to:
  /// **'Your opponent offers a draw.'**
  String get drawOfferBody;

  /// No description provided for @takeBack.
  ///
  /// In en, this message translates to:
  /// **'Take back'**
  String get takeBack;

  /// No description provided for @newGame.
  ///
  /// In en, this message translates to:
  /// **'New game'**
  String get newGame;

  /// No description provided for @mainMenu.
  ///
  /// In en, this message translates to:
  /// **'Main menu'**
  String get mainMenu;

  /// No description provided for @flipBoard.
  ///
  /// In en, this message translates to:
  /// **'Flip board'**
  String get flipBoard;

  /// No description provided for @autoFlipOn.
  ///
  /// In en, this message translates to:
  /// **'Auto-flip: on'**
  String get autoFlipOn;

  /// No description provided for @autoFlipOff.
  ///
  /// In en, this message translates to:
  /// **'Auto-flip: off'**
  String get autoFlipOff;

  /// No description provided for @saveGame.
  ///
  /// In en, this message translates to:
  /// **'Save game'**
  String get saveGame;

  /// No description provided for @aiMove.
  ///
  /// In en, this message translates to:
  /// **'AI move (current side)'**
  String get aiMove;

  /// No description provided for @playAgain.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get playAgain;

  /// No description provided for @analyzeGame.
  ///
  /// In en, this message translates to:
  /// **'Analyze game'**
  String get analyzeGame;

  /// No description provided for @gameSaved.
  ///
  /// In en, this message translates to:
  /// **'Game saved'**
  String get gameSaved;

  /// No description provided for @boardDesync.
  ///
  /// In en, this message translates to:
  /// **'Board desync — game aborted'**
  String get boardDesync;

  /// No description provided for @youResigned.
  ///
  /// In en, this message translates to:
  /// **'You resigned — you lose'**
  String get youResigned;

  /// No description provided for @opponentResigned.
  ///
  /// In en, this message translates to:
  /// **'Opponent resigned — you win'**
  String get opponentResigned;

  /// No description provided for @drawAgreed.
  ///
  /// In en, this message translates to:
  /// **'Draw agreed'**
  String get drawAgreed;

  /// No description provided for @opponentDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Opponent disconnected'**
  String get opponentDisconnected;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @gameName.
  ///
  /// In en, this message translates to:
  /// **'Game name'**
  String get gameName;

  /// No description provided for @myGame.
  ///
  /// In en, this message translates to:
  /// **'My game'**
  String get myGame;

  /// No description provided for @analysis.
  ///
  /// In en, this message translates to:
  /// **'Analysis'**
  String get analysis;

  /// No description provided for @white.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get white;

  /// No description provided for @black.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get black;

  /// No description provided for @accuracy.
  ///
  /// In en, this message translates to:
  /// **'accuracy'**
  String get accuracy;

  /// No description provided for @analyzingProgress.
  ///
  /// In en, this message translates to:
  /// **'Analyzing {done}/{total}…'**
  String analyzingProgress(Object done, Object total);

  /// No description provided for @preparingAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Preparing analysis…'**
  String get preparingAnalysis;

  /// No description provided for @clsBrilliant.
  ///
  /// In en, this message translates to:
  /// **'Brilliant'**
  String get clsBrilliant;

  /// No description provided for @clsGreat.
  ///
  /// In en, this message translates to:
  /// **'Great'**
  String get clsGreat;

  /// No description provided for @clsBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get clsBest;

  /// No description provided for @clsGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get clsGood;

  /// No description provided for @clsBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get clsBook;

  /// No description provided for @clsInaccuracy.
  ///
  /// In en, this message translates to:
  /// **'Inaccuracy'**
  String get clsInaccuracy;

  /// No description provided for @clsMiss.
  ///
  /// In en, this message translates to:
  /// **'Miss'**
  String get clsMiss;

  /// No description provided for @clsMistake.
  ///
  /// In en, this message translates to:
  /// **'Mistake'**
  String get clsMistake;

  /// No description provided for @clsBlunder.
  ///
  /// In en, this message translates to:
  /// **'Blunder'**
  String get clsBlunder;

  /// No description provided for @coachBrilliant.
  ///
  /// In en, this message translates to:
  /// **'Brilliant — a winning sacrifice.'**
  String get coachBrilliant;

  /// No description provided for @coachGreat.
  ///
  /// In en, this message translates to:
  /// **'Great — the only move that holds.'**
  String get coachGreat;

  /// No description provided for @coachBest.
  ///
  /// In en, this message translates to:
  /// **'Best move.'**
  String get coachBest;

  /// No description provided for @coachBook.
  ///
  /// In en, this message translates to:
  /// **'A known opening move.'**
  String get coachBook;

  /// No description provided for @coachGood.
  ///
  /// In en, this message translates to:
  /// **'A good move.'**
  String get coachGood;

  /// No description provided for @coachInaccuracy.
  ///
  /// In en, this message translates to:
  /// **'Inaccuracy — {best} was a little better.'**
  String coachInaccuracy(Object best);

  /// No description provided for @coachMiss.
  ///
  /// In en, this message translates to:
  /// **'Missed a winning chance — {best} was much stronger.'**
  String coachMiss(Object best);

  /// No description provided for @coachMistake.
  ///
  /// In en, this message translates to:
  /// **'Mistake — {best} was stronger.'**
  String coachMistake(Object best);

  /// No description provided for @coachBlunder.
  ///
  /// In en, this message translates to:
  /// **'Blunder — {best} was much better.'**
  String coachBlunder(Object best);

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @boardThemeLabel.
  ///
  /// In en, this message translates to:
  /// **'Board theme'**
  String get boardThemeLabel;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @accessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get accessibility;

  /// No description provided for @highContrast.
  ///
  /// In en, this message translates to:
  /// **'High-contrast board'**
  String get highContrast;

  /// No description provided for @colorblindSafe.
  ///
  /// In en, this message translates to:
  /// **'Colourblind-safe move colours'**
  String get colorblindSafe;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @gameplay.
  ///
  /// In en, this message translates to:
  /// **'Gameplay'**
  String get gameplay;

  /// No description provided for @sound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// No description provided for @moveHints.
  ///
  /// In en, this message translates to:
  /// **'Move hints'**
  String get moveHints;

  /// No description provided for @haptics.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get haptics;

  /// No description provided for @animationSpeed.
  ///
  /// In en, this message translates to:
  /// **'Animation speed'**
  String get animationSpeed;

  /// No description provided for @defaultTimeControl.
  ///
  /// In en, this message translates to:
  /// **'Default time control'**
  String get defaultTimeControl;

  /// No description provided for @defaultDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Default difficulty'**
  String get defaultDifficulty;

  /// No description provided for @hostGame.
  ///
  /// In en, this message translates to:
  /// **'Host game'**
  String get hostGame;

  /// No description provided for @joinGame.
  ///
  /// In en, this message translates to:
  /// **'Join game'**
  String get joinGame;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @yourColour.
  ///
  /// In en, this message translates to:
  /// **'Your colour'**
  String get yourColour;

  /// No description provided for @colourWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get colourWhite;

  /// No description provided for @colourBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get colourBlack;

  /// No description provided for @colourRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get colourRandom;

  /// No description provided for @hostAGame.
  ///
  /// In en, this message translates to:
  /// **'Host a game'**
  String get hostAGame;

  /// No description provided for @joinOnNetwork.
  ///
  /// In en, this message translates to:
  /// **'Join a game on this network'**
  String get joinOnNetwork;

  /// No description provided for @searchingHosts.
  ///
  /// In en, this message translates to:
  /// **'Searching for hosts…'**
  String get searchingHosts;

  /// No description provided for @waitingOpponent.
  ///
  /// In en, this message translates to:
  /// **'Waiting for an opponent to connect…'**
  String get waitingOpponent;

  /// No description provided for @lanGame.
  ///
  /// In en, this message translates to:
  /// **'LAN game'**
  String get lanGame;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get typeMessage;

  /// No description provided for @savedGames.
  ///
  /// In en, this message translates to:
  /// **'Saved games'**
  String get savedGames;

  /// No description provided for @noSavedGames.
  ///
  /// In en, this message translates to:
  /// **'No saved games yet'**
  String get noSavedGames;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @renameGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename game'**
  String get renameGameTitle;

  /// No description provided for @playFromPosition.
  ///
  /// In en, this message translates to:
  /// **'Play from Position'**
  String get playFromPosition;

  /// No description provided for @pasteFen.
  ///
  /// In en, this message translates to:
  /// **'Paste a FEN string'**
  String get pasteFen;

  /// No description provided for @fenHint.
  ///
  /// In en, this message translates to:
  /// **'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'**
  String get fenHint;

  /// No description provided for @invalidFen.
  ///
  /// In en, this message translates to:
  /// **'Invalid FEN — check the position string'**
  String get invalidFen;

  /// No description provided for @useStartPosition.
  ///
  /// In en, this message translates to:
  /// **'Use start position'**
  String get useStartPosition;

  /// No description provided for @loadPosition.
  ///
  /// In en, this message translates to:
  /// **'Load position'**
  String get loadPosition;

  /// No description provided for @sideToPlay.
  ///
  /// In en, this message translates to:
  /// **'Side to play is set by the FEN'**
  String get sideToPlay;

  /// No description provided for @exportPgn.
  ///
  /// In en, this message translates to:
  /// **'Export PGN'**
  String get exportPgn;

  /// No description provided for @copyPgn.
  ///
  /// In en, this message translates to:
  /// **'Copy PGN'**
  String get copyPgn;

  /// No description provided for @copyMoves.
  ///
  /// In en, this message translates to:
  /// **'Copy moves'**
  String get copyMoves;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @game.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get game;

  /// No description provided for @singlePlayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Single Player vs AI'**
  String get singlePlayerTitle;

  /// No description provided for @twoPlayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Two players — same device'**
  String get twoPlayerTitle;

  /// No description provided for @lanTitle.
  ///
  /// In en, this message translates to:
  /// **'Two players — LAN'**
  String get lanTitle;

  /// No description provided for @playAs.
  ///
  /// In en, this message translates to:
  /// **'Play as'**
  String get playAs;

  /// No description provided for @difficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficulty;

  /// No description provided for @timeControl.
  ///
  /// In en, this message translates to:
  /// **'Time control'**
  String get timeControl;

  /// No description provided for @startGame.
  ///
  /// In en, this message translates to:
  /// **'Start game'**
  String get startGame;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @tcInfinite.
  ///
  /// In en, this message translates to:
  /// **'Infinite'**
  String get tcInfinite;

  /// No description provided for @diffBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get diffBeginner;

  /// No description provided for @diffEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get diffEasy;

  /// No description provided for @diffMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get diffMedium;

  /// No description provided for @diffHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get diffHard;

  /// No description provided for @diffExpert.
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get diffExpert;

  /// No description provided for @baseMinutes.
  ///
  /// In en, this message translates to:
  /// **'Base minutes'**
  String get baseMinutes;

  /// No description provided for @incrementSeconds.
  ///
  /// In en, this message translates to:
  /// **'Increment seconds'**
  String get incrementSeconds;

  /// No description provided for @baseTimeError.
  ///
  /// In en, this message translates to:
  /// **'Base time must be at least 1 minute'**
  String get baseTimeError;

  /// No description provided for @searchDepth.
  ///
  /// In en, this message translates to:
  /// **'Search depth'**
  String get searchDepth;

  /// No description provided for @timePerMove.
  ///
  /// In en, this message translates to:
  /// **'Time/move (ms)'**
  String get timePerMove;

  /// No description provided for @topNRandom.
  ///
  /// In en, this message translates to:
  /// **'Top-N random'**
  String get topNRandom;

  /// No description provided for @blunderChance.
  ///
  /// In en, this message translates to:
  /// **'Blunder chance'**
  String get blunderChance;

  /// No description provided for @evalNoise.
  ///
  /// In en, this message translates to:
  /// **'Eval noise (cp)'**
  String get evalNoise;

  /// No description provided for @puzzlesSolved.
  ///
  /// In en, this message translates to:
  /// **'{solved}/{total} solved'**
  String puzzlesSolved(Object solved, Object total);

  /// No description provided for @alreadySolved.
  ///
  /// In en, this message translates to:
  /// **'already solved'**
  String get alreadySolved;

  /// No description provided for @puzzleWrong.
  ///
  /// In en, this message translates to:
  /// **'Not the move — try again'**
  String get puzzleWrong;

  /// No description provided for @puzzleSolvedMsg.
  ///
  /// In en, this message translates to:
  /// **'Solved! ✓  Tap ▶ for the next puzzle'**
  String get puzzleSolvedMsg;

  /// No description provided for @puzzleFooter.
  ///
  /// In en, this message translates to:
  /// **'Puzzle {index}/{total}  ·  rating {rating}  ·  streak {streak} (best {best})'**
  String puzzleFooter(
    Object index,
    Object total,
    Object rating,
    Object streak,
    Object best,
  );

  /// No description provided for @loadPuzzlesFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load puzzles'**
  String get loadPuzzlesFailed;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @hint.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get hint;

  /// No description provided for @restartPuzzle.
  ///
  /// In en, this message translates to:
  /// **'Restart puzzle'**
  String get restartPuzzle;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @savedCorrupt.
  ///
  /// In en, this message translates to:
  /// **'Saved game was corrupt; loaded partially'**
  String get savedCorrupt;

  /// No description provided for @menuBughouse.
  ///
  /// In en, this message translates to:
  /// **'Bughouse'**
  String get menuBughouse;

  /// No description provided for @bugMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get bugMode;

  /// No description provided for @bugHotSeat.
  ///
  /// In en, this message translates to:
  /// **'Hot-seat (4 players)'**
  String get bugHotSeat;

  /// No description provided for @bugVsAi.
  ///
  /// In en, this message translates to:
  /// **'vs Computer'**
  String get bugVsAi;

  /// No description provided for @bugYourSeat.
  ///
  /// In en, this message translates to:
  /// **'Your seat'**
  String get bugYourSeat;

  /// No description provided for @bugBoardA.
  ///
  /// In en, this message translates to:
  /// **'Board A'**
  String get bugBoardA;

  /// No description provided for @bugBoardB.
  ///
  /// In en, this message translates to:
  /// **'Board B'**
  String get bugBoardB;

  /// No description provided for @bugWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get bugWhite;

  /// No description provided for @bugBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get bugBlack;

  /// No description provided for @bugTeamWins.
  ///
  /// In en, this message translates to:
  /// **'Team {team} wins'**
  String bugTeamWins(String team);

  /// No description provided for @bugStart.
  ///
  /// In en, this message translates to:
  /// **'Start match'**
  String get bugStart;

  /// No description provided for @bugLan.
  ///
  /// In en, this message translates to:
  /// **'LAN'**
  String get bugLan;

  /// No description provided for @bugHostMatch.
  ///
  /// In en, this message translates to:
  /// **'Host match'**
  String get bugHostMatch;

  /// No description provided for @bugJoinMatch.
  ///
  /// In en, this message translates to:
  /// **'Join a match'**
  String get bugJoinMatch;

  /// No description provided for @bugWaitingHost.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the host to start…'**
  String get bugWaitingHost;

  /// No description provided for @bugPlayersJoined.
  ///
  /// In en, this message translates to:
  /// **'Players joined'**
  String get bugPlayersJoined;

  /// No description provided for @bugAssignSeats.
  ///
  /// In en, this message translates to:
  /// **'Assign the four seats'**
  String get bugAssignSeats;

  /// No description provided for @bugSeatHost.
  ///
  /// In en, this message translates to:
  /// **'Host (you)'**
  String get bugSeatHost;

  /// No description provided for @variant.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get variant;

  /// No description provided for @vStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get vStandard;

  /// No description provided for @vThreeCheck.
  ///
  /// In en, this message translates to:
  /// **'Three-check'**
  String get vThreeCheck;

  /// No description provided for @vKingOfTheHill.
  ///
  /// In en, this message translates to:
  /// **'King of the Hill'**
  String get vKingOfTheHill;

  /// No description provided for @vChess960.
  ///
  /// In en, this message translates to:
  /// **'Chess960'**
  String get vChess960;

  /// No description provided for @vAtomic.
  ///
  /// In en, this message translates to:
  /// **'Atomic'**
  String get vAtomic;

  /// No description provided for @vCrazyhouse.
  ///
  /// In en, this message translates to:
  /// **'Crazyhouse'**
  String get vCrazyhouse;

  /// No description provided for @vFogOfWar.
  ///
  /// In en, this message translates to:
  /// **'Fog of War'**
  String get vFogOfWar;

  /// No description provided for @menuFourPlayer.
  ///
  /// In en, this message translates to:
  /// **'4-Player'**
  String get menuFourPlayer;

  /// No description provided for @fourFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get fourFormat;

  /// No description provided for @fourFFA.
  ///
  /// In en, this message translates to:
  /// **'Free-for-all'**
  String get fourFFA;

  /// No description provided for @fourTeams.
  ///
  /// In en, this message translates to:
  /// **'Teams (2v2)'**
  String get fourTeams;

  /// No description provided for @fourVsBots.
  ///
  /// In en, this message translates to:
  /// **'vs Bots'**
  String get fourVsBots;

  /// No description provided for @fourYourSeats.
  ///
  /// In en, this message translates to:
  /// **'Your seats'**
  String get fourYourSeats;

  /// No description provided for @fourRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get fourRed;

  /// No description provided for @fourBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get fourBlue;

  /// No description provided for @fourYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get fourYellow;

  /// No description provided for @fourGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get fourGreen;

  /// No description provided for @fourTeamWins.
  ///
  /// In en, this message translates to:
  /// **'{team} win'**
  String fourTeamWins(String team);

  /// No description provided for @fourWins.
  ///
  /// In en, this message translates to:
  /// **'{player} wins'**
  String fourWins(String player);

  /// No description provided for @fogPassDevice.
  ///
  /// In en, this message translates to:
  /// **'Pass the device to {color}'**
  String fogPassDevice(String color);

  /// No description provided for @fogTapReveal.
  ///
  /// In en, this message translates to:
  /// **'Tap to reveal your turn'**
  String get fogTapReveal;

  /// No description provided for @checksLabel.
  ///
  /// In en, this message translates to:
  /// **'Checks'**
  String get checksLabel;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @donate.
  ///
  /// In en, this message translates to:
  /// **'Donate'**
  String get donate;

  /// No description provided for @donateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Support development via GitHub Sponsors'**
  String get donateSubtitle;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @checkingForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get checkingForUpdates;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the latest version.'**
  String get upToDate;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailable;

  /// No description provided for @newVersionAvailable.
  ///
  /// In en, this message translates to:
  /// **'A new version is available:'**
  String get newVersionAvailable;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'ja',
    'ko',
    'ru',
    'tr',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
