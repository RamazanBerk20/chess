// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Chess';

  @override
  String get menuSinglePlayer => 'Single Player';

  @override
  String get menuTwoPlayers => 'Two Players';

  @override
  String get menuLan => 'Play over LAN';

  @override
  String get menuPuzzles => 'Puzzles';

  @override
  String get menuResume => 'Resume Game';

  @override
  String get menuSettings => 'Settings';

  @override
  String get menuPlayFromPosition => 'Play from Position';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get copy => 'Copy';

  @override
  String get share => 'Share';

  @override
  String get start => 'Start';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get send => 'Send';

  @override
  String get whiteToMove => 'White to move';

  @override
  String get blackToMove => 'Black to move';

  @override
  String get whiteToMoveCheck => 'White to move — check!';

  @override
  String get blackToMoveCheck => 'Black to move — check!';

  @override
  String get checkmateWhiteWins => 'Checkmate — White wins';

  @override
  String get checkmateBlackWins => 'Checkmate — Black wins';

  @override
  String get whiteWinsOnTime => 'White wins on time';

  @override
  String get blackWinsOnTime => 'Black wins on time';

  @override
  String get drawStalemate => 'Draw — stalemate';

  @override
  String get drawFiftyMove => 'Draw — fifty-move rule';

  @override
  String get drawThreefold => 'Draw — threefold repetition';

  @override
  String get drawInsufficient => 'Draw — insufficient material';

  @override
  String get resign => 'Resign';

  @override
  String get offerDraw => 'Offer draw';

  @override
  String get drawOfferTitle => 'Draw offer';

  @override
  String get drawOfferBody => 'Your opponent offers a draw.';

  @override
  String get takeBack => 'Take back';

  @override
  String get newGame => 'New game';

  @override
  String get mainMenu => 'Main menu';

  @override
  String get flipBoard => 'Flip board';

  @override
  String get autoFlipOn => 'Auto-flip: on';

  @override
  String get autoFlipOff => 'Auto-flip: off';

  @override
  String get saveGame => 'Save game';

  @override
  String get aiMove => 'AI move (current side)';

  @override
  String get playAgain => 'Play again';

  @override
  String get analyzeGame => 'Analyze game';

  @override
  String get gameSaved => 'Game saved';

  @override
  String get boardDesync => 'Board desync — game aborted';

  @override
  String get youResigned => 'You resigned — you lose';

  @override
  String get opponentResigned => 'Opponent resigned — you win';

  @override
  String get drawAgreed => 'Draw agreed';

  @override
  String get opponentDisconnected => 'Opponent disconnected';

  @override
  String get name => 'Name';

  @override
  String get gameName => 'Game name';

  @override
  String get myGame => 'My game';

  @override
  String get analysis => 'Analysis';

  @override
  String get white => 'White';

  @override
  String get black => 'Black';

  @override
  String get accuracy => 'accuracy';

  @override
  String analyzingProgress(Object done, Object total) {
    return 'Analyzing $done/$total…';
  }

  @override
  String get preparingAnalysis => 'Preparing analysis…';

  @override
  String get clsBrilliant => 'Brilliant';

  @override
  String get clsGreat => 'Great';

  @override
  String get clsBest => 'Best';

  @override
  String get clsGood => 'Good';

  @override
  String get clsBook => 'Book';

  @override
  String get clsInaccuracy => 'Inaccuracy';

  @override
  String get clsMiss => 'Miss';

  @override
  String get clsMistake => 'Mistake';

  @override
  String get clsBlunder => 'Blunder';

  @override
  String get coachBrilliant => 'Brilliant — a winning sacrifice.';

  @override
  String get coachGreat => 'Great — the only move that holds.';

  @override
  String get coachBest => 'Best move.';

  @override
  String get coachBook => 'A known opening move.';

  @override
  String get coachGood => 'A good move.';

  @override
  String coachInaccuracy(Object best) {
    return 'Inaccuracy — $best was a little better.';
  }

  @override
  String coachMiss(Object best) {
    return 'Missed a winning chance — $best was much stronger.';
  }

  @override
  String coachMistake(Object best) {
    return 'Mistake — $best was stronger.';
  }

  @override
  String coachBlunder(Object best) {
    return 'Blunder — $best was much better.';
  }

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get boardThemeLabel => 'Board theme';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get accessibility => 'Accessibility';

  @override
  String get highContrast => 'High-contrast board';

  @override
  String get colorblindSafe => 'Colourblind-safe move colours';

  @override
  String get textSize => 'Text size';

  @override
  String get gameplay => 'Gameplay';

  @override
  String get sound => 'Sound';

  @override
  String get moveHints => 'Move hints';

  @override
  String get haptics => 'Haptics';

  @override
  String get animationSpeed => 'Animation speed';

  @override
  String get defaultTimeControl => 'Default time control';

  @override
  String get defaultDifficulty => 'Default difficulty';

  @override
  String get hostGame => 'Host game';

  @override
  String get joinGame => 'Join game';

  @override
  String get yourName => 'Your name';

  @override
  String get yourColour => 'Your colour';

  @override
  String get colourWhite => 'White';

  @override
  String get colourBlack => 'Black';

  @override
  String get colourRandom => 'Random';

  @override
  String get hostAGame => 'Host a game';

  @override
  String get joinOnNetwork => 'Join a game on this network';

  @override
  String get searchingHosts => 'Searching for hosts…';

  @override
  String get waitingOpponent => 'Waiting for an opponent to connect…';

  @override
  String get lanGame => 'LAN game';

  @override
  String get chat => 'Chat';

  @override
  String get typeMessage => 'Type a message…';

  @override
  String get savedGames => 'Saved games';

  @override
  String get noSavedGames => 'No saved games yet';

  @override
  String get resume => 'Resume';

  @override
  String get renameGameTitle => 'Rename game';

  @override
  String get playFromPosition => 'Play from Position';

  @override
  String get pasteFen => 'Paste a FEN string';

  @override
  String get fenHint =>
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  String get invalidFen => 'Invalid FEN — check the position string';

  @override
  String get useStartPosition => 'Use start position';

  @override
  String get loadPosition => 'Load position';

  @override
  String get sideToPlay => 'Side to play is set by the FEN';

  @override
  String get exportPgn => 'Export PGN';

  @override
  String get copyPgn => 'Copy PGN';

  @override
  String get copyMoves => 'Copy moves';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get game => 'Game';

  @override
  String get singlePlayerTitle => 'Single Player vs AI';

  @override
  String get twoPlayerTitle => 'Two players — same device';

  @override
  String get lanTitle => 'Two players — LAN';

  @override
  String get playAs => 'Play as';

  @override
  String get difficulty => 'Difficulty';

  @override
  String get timeControl => 'Time control';

  @override
  String get startGame => 'Start game';

  @override
  String get custom => 'Custom';

  @override
  String get tcInfinite => 'Infinite';

  @override
  String get diffBeginner => 'Beginner';

  @override
  String get diffEasy => 'Easy';

  @override
  String get diffMedium => 'Medium';

  @override
  String get diffHard => 'Hard';

  @override
  String get diffExpert => 'Expert';

  @override
  String get baseMinutes => 'Base minutes';

  @override
  String get incrementSeconds => 'Increment seconds';

  @override
  String get baseTimeError => 'Base time must be at least 1 minute';

  @override
  String get searchDepth => 'Search depth';

  @override
  String get timePerMove => 'Time/move (ms)';

  @override
  String get topNRandom => 'Top-N random';

  @override
  String get blunderChance => 'Blunder chance';

  @override
  String get evalNoise => 'Eval noise (cp)';

  @override
  String puzzlesSolved(Object solved, Object total) {
    return '$solved/$total solved';
  }

  @override
  String get alreadySolved => 'already solved';

  @override
  String get puzzleWrong => 'Not the move — try again';

  @override
  String get puzzleSolvedMsg => 'Solved! ✓  Tap ▶ for the next puzzle';

  @override
  String puzzleFooter(
    Object index,
    Object total,
    Object rating,
    Object streak,
    Object best,
  ) {
    return 'Puzzle $index/$total  ·  rating $rating  ·  streak $streak (best $best)';
  }

  @override
  String get loadPuzzlesFailed => 'Failed to load puzzles';

  @override
  String get previous => 'Previous';

  @override
  String get hint => 'Hint';

  @override
  String get restartPuzzle => 'Restart puzzle';

  @override
  String get next => 'Next';

  @override
  String get savedCorrupt => 'Saved game was corrupt; loaded partially';

  @override
  String get menuBughouse => 'Bughouse';

  @override
  String get bugMode => 'Mode';

  @override
  String get bugHotSeat => 'Hot-seat (4 players)';

  @override
  String get bugVsAi => 'vs Computer';

  @override
  String get bugYourSeat => 'Your seat';

  @override
  String get bugBoardA => 'Board A';

  @override
  String get bugBoardB => 'Board B';

  @override
  String get bugWhite => 'White';

  @override
  String get bugBlack => 'Black';

  @override
  String bugTeamWins(String team) {
    return 'Team $team wins';
  }

  @override
  String get bugStart => 'Start match';

  @override
  String get bugLan => 'LAN';

  @override
  String get bugHostMatch => 'Host match';

  @override
  String get bugJoinMatch => 'Join a match';

  @override
  String get bugWaitingHost => 'Waiting for the host to start…';

  @override
  String get bugPlayersJoined => 'Players joined';

  @override
  String get bugAssignSeats => 'Assign the four seats';

  @override
  String get bugSeatHost => 'Host (you)';

  @override
  String get variant => 'Variant';

  @override
  String get vStandard => 'Standard';

  @override
  String get vThreeCheck => 'Three-check';

  @override
  String get vKingOfTheHill => 'King of the Hill';

  @override
  String get vChess960 => 'Chess960';

  @override
  String get vAtomic => 'Atomic';

  @override
  String get vCrazyhouse => 'Crazyhouse';

  @override
  String get vFogOfWar => 'Fog of War';

  @override
  String get menuFourPlayer => '4-Player';

  @override
  String get fourFormat => 'Format';

  @override
  String get fourFFA => 'Free-for-all';

  @override
  String get fourTeams => 'Teams (2v2)';

  @override
  String get fourVsBots => 'vs Bots';

  @override
  String get fourYourSeats => 'Your seats';

  @override
  String get fourRed => 'Red';

  @override
  String get fourBlue => 'Blue';

  @override
  String get fourYellow => 'Yellow';

  @override
  String get fourGreen => 'Green';

  @override
  String fourTeamWins(String team) {
    return '$team win';
  }

  @override
  String fourWins(String player) {
    return '$player wins';
  }

  @override
  String fogPassDevice(String color) {
    return 'Pass the device to $color';
  }

  @override
  String get fogTapReveal => 'Tap to reveal your turn';

  @override
  String get checksLabel => 'Checks';

  @override
  String get support => 'Support';

  @override
  String get donate => 'Donate';

  @override
  String get donateSubtitle => 'Support development via GitHub Sponsors';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get checkingForUpdates => 'Checking for updates…';

  @override
  String get upToDate => 'You\'re on the latest version.';

  @override
  String get updateAvailable => 'Update available';

  @override
  String get newVersionAvailable => 'A new version is available:';

  @override
  String get download => 'Download';

  @override
  String get later => 'Later';

  @override
  String get about => 'About';
}
