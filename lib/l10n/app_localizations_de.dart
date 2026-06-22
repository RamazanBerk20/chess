// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Schach';

  @override
  String get menuSinglePlayer => 'Einzelspieler';

  @override
  String get menuTwoPlayers => 'Zwei Spieler';

  @override
  String get menuLan => 'Über LAN spielen';

  @override
  String get menuPuzzles => 'Taktikaufgaben';

  @override
  String get menuResume => 'Partie fortsetzen';

  @override
  String get menuSettings => 'Einstellungen';

  @override
  String get menuPlayFromPosition => 'Aus Stellung spielen';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get rename => 'Umbenennen';

  @override
  String get close => 'Schließen';

  @override
  String get retry => 'Wiederholen';

  @override
  String get copy => 'Kopieren';

  @override
  String get share => 'Teilen';

  @override
  String get start => 'Start';

  @override
  String get accept => 'Annehmen';

  @override
  String get decline => 'Ablehnen';

  @override
  String get send => 'Senden';

  @override
  String get whiteToMove => 'Weiß am Zug';

  @override
  String get blackToMove => 'Schwarz am Zug';

  @override
  String get whiteToMoveCheck => 'Weiß am Zug — Schach!';

  @override
  String get blackToMoveCheck => 'Schwarz am Zug — Schach!';

  @override
  String get checkmateWhiteWins => 'Schachmatt — Weiß gewinnt';

  @override
  String get checkmateBlackWins => 'Schachmatt — Schwarz gewinnt';

  @override
  String get whiteWinsOnTime => 'Weiß gewinnt auf Zeit';

  @override
  String get blackWinsOnTime => 'Schwarz gewinnt auf Zeit';

  @override
  String get drawStalemate => 'Remis — Patt';

  @override
  String get drawFiftyMove => 'Remis — 50-Züge-Regel';

  @override
  String get drawThreefold => 'Remis — dreifache Stellungswiederholung';

  @override
  String get drawInsufficient => 'Remis — ungenügendes Material';

  @override
  String get resign => 'Aufgeben';

  @override
  String get offerDraw => 'Remis anbieten';

  @override
  String get drawOfferTitle => 'Remisangebot';

  @override
  String get drawOfferBody => 'Dein Gegner bietet ein Remis an.';

  @override
  String get takeBack => 'Zug zurücknehmen';

  @override
  String get newGame => 'Neue Partie';

  @override
  String get mainMenu => 'Hauptmenü';

  @override
  String get flipBoard => 'Brett drehen';

  @override
  String get autoFlipOn => 'Automatisches Drehen: an';

  @override
  String get autoFlipOff => 'Automatisches Drehen: aus';

  @override
  String get saveGame => 'Partie speichern';

  @override
  String get aiMove => 'KI-Zug (aktuelle Seite)';

  @override
  String get playAgain => 'Erneut spielen';

  @override
  String get analyzeGame => 'Partie analysieren';

  @override
  String get gameSaved => 'Partie gespeichert';

  @override
  String get boardDesync =>
      'Brettsynchronisation verloren — Partie abgebrochen';

  @override
  String get youResigned => 'Du hast aufgegeben — du verlierst';

  @override
  String get opponentResigned => 'Gegner hat aufgegeben — du gewinnst';

  @override
  String get drawAgreed => 'Remis vereinbart';

  @override
  String get opponentDisconnected => 'Gegner hat die Verbindung getrennt';

  @override
  String get name => 'Name';

  @override
  String get gameName => 'Partiename';

  @override
  String get myGame => 'Meine Partie';

  @override
  String get analysis => 'Analyse';

  @override
  String get white => 'Weiß';

  @override
  String get black => 'Schwarz';

  @override
  String get accuracy => 'Genauigkeit';

  @override
  String analyzingProgress(Object done, Object total) {
    return 'Analysiere $done/$total…';
  }

  @override
  String get preparingAnalysis => 'Analyse wird vorbereitet…';

  @override
  String get clsBrilliant => 'Brillant';

  @override
  String get clsGreat => 'Großartig';

  @override
  String get clsBest => 'Bester Zug';

  @override
  String get clsGood => 'Gut';

  @override
  String get clsBook => 'Eröffnung';

  @override
  String get clsInaccuracy => 'Ungenauigkeit';

  @override
  String get clsMiss => 'Verpasst';

  @override
  String get clsMistake => 'Fehler';

  @override
  String get clsBlunder => 'Grober Fehler';

  @override
  String get coachBrilliant => 'Brillant — ein gewinnbringendes Opfer.';

  @override
  String get coachGreat => 'Großartig — der einzige Zug, der hält.';

  @override
  String get coachBest => 'Bester Zug.';

  @override
  String get coachBook => 'Ein bekannter Eröffnungszug.';

  @override
  String get coachGood => 'Ein guter Zug.';

  @override
  String coachInaccuracy(Object best) {
    return 'Ungenauigkeit — $best war etwas besser.';
  }

  @override
  String coachMiss(Object best) {
    return 'Eine Gewinnchance verpasst — $best war deutlich stärker.';
  }

  @override
  String coachMistake(Object best) {
    return 'Fehler — $best war stärker.';
  }

  @override
  String coachBlunder(Object best) {
    return 'Grober Fehler — $best war deutlich besser.';
  }

  @override
  String get settings => 'Einstellungen';

  @override
  String get appearance => 'Darstellung';

  @override
  String get boardThemeLabel => 'Brett-Design';

  @override
  String get theme => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'Systemstandard';

  @override
  String get accessibility => 'Barrierefreiheit';

  @override
  String get highContrast => 'Kontrastreiches Brett';

  @override
  String get colorblindSafe => 'Farbenblindheitssichere Zugfarben';

  @override
  String get textSize => 'Textgröße';

  @override
  String get gameplay => 'Spielablauf';

  @override
  String get sound => 'Ton';

  @override
  String get moveHints => 'Zughinweise';

  @override
  String get haptics => 'Haptisches Feedback';

  @override
  String get animationSpeed => 'Animationsgeschwindigkeit';

  @override
  String get defaultTimeControl => 'Standard-Bedenkzeit';

  @override
  String get defaultDifficulty => 'Standard-Schwierigkeit';

  @override
  String get hostGame => 'Partie hosten';

  @override
  String get joinGame => 'Partie beitreten';

  @override
  String get yourName => 'Dein Name';

  @override
  String get yourColour => 'Deine Farbe';

  @override
  String get colourWhite => 'Weiß';

  @override
  String get colourBlack => 'Schwarz';

  @override
  String get colourRandom => 'Zufällig';

  @override
  String get hostAGame => 'Eine Partie hosten';

  @override
  String get joinOnNetwork => 'Einer Partie in diesem Netzwerk beitreten';

  @override
  String get searchingHosts => 'Suche nach Hosts…';

  @override
  String get waitingOpponent => 'Warte auf Verbindung eines Gegners…';

  @override
  String get lanGame => 'LAN-Partie';

  @override
  String get chat => 'Chat';

  @override
  String get typeMessage => 'Nachricht eingeben…';

  @override
  String get savedGames => 'Gespeicherte Partien';

  @override
  String get noSavedGames => 'Noch keine gespeicherten Partien';

  @override
  String get resume => 'Fortsetzen';

  @override
  String get renameGameTitle => 'Partie umbenennen';

  @override
  String get playFromPosition => 'Aus Stellung spielen';

  @override
  String get pasteFen => 'FEN-Zeichenkette einfügen';

  @override
  String get fenHint =>
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  String get invalidFen =>
      'Ungültige FEN — überprüfe die Stellungszeichenkette';

  @override
  String get useStartPosition => 'Grundstellung verwenden';

  @override
  String get loadPosition => 'Stellung laden';

  @override
  String get sideToPlay => 'Die ziehende Seite wird durch die FEN bestimmt';

  @override
  String get exportPgn => 'PGN exportieren';

  @override
  String get copyPgn => 'PGN kopieren';

  @override
  String get copyMoves => 'Züge kopieren';

  @override
  String get copiedToClipboard => 'In die Zwischenablage kopiert';

  @override
  String get game => 'Partie';

  @override
  String get singlePlayerTitle => 'Einzelspieler gegen KI';

  @override
  String get twoPlayerTitle => 'Zwei Spieler — gleiches Gerät';

  @override
  String get lanTitle => 'Zwei Spieler — LAN';

  @override
  String get playAs => 'Spielen als';

  @override
  String get difficulty => 'Schwierigkeit';

  @override
  String get timeControl => 'Bedenkzeit';

  @override
  String get startGame => 'Partie starten';

  @override
  String get custom => 'Benutzerdefiniert';

  @override
  String get tcInfinite => 'Unbegrenzt';

  @override
  String get diffBeginner => 'Anfänger';

  @override
  String get diffEasy => 'Leicht';

  @override
  String get diffMedium => 'Mittel';

  @override
  String get diffHard => 'Schwer';

  @override
  String get diffExpert => 'Experte';

  @override
  String get baseMinutes => 'Grundzeit (Minuten)';

  @override
  String get incrementSeconds => 'Inkrement (Sekunden)';

  @override
  String get baseTimeError => 'Die Grundzeit muss mindestens 1 Minute betragen';

  @override
  String get searchDepth => 'Suchtiefe';

  @override
  String get timePerMove => 'Zeit/Zug (ms)';

  @override
  String get topNRandom => 'Top-N zufällig';

  @override
  String get blunderChance => 'Patzer-Wahrscheinlichkeit';

  @override
  String get evalNoise => 'Bewertungsrauschen (cp)';

  @override
  String puzzlesSolved(Object solved, Object total) {
    return '$solved/$total gelöst';
  }

  @override
  String get alreadySolved => 'bereits gelöst';

  @override
  String get puzzleWrong => 'Nicht der richtige Zug — versuche es erneut';

  @override
  String get puzzleSolvedMsg => 'Gelöst! ✓  Tippe auf ▶ für das nächste Puzzle';

  @override
  String puzzleFooter(
    Object index,
    Object total,
    Object rating,
    Object streak,
    Object best,
  ) {
    return 'Puzzle $index/$total  ·  Wertung $rating  ·  Serie $streak (Bestwert $best)';
  }

  @override
  String get loadPuzzlesFailed => 'Puzzles konnten nicht geladen werden';

  @override
  String get previous => 'Zurück';

  @override
  String get hint => 'Tipp';

  @override
  String get restartPuzzle => 'Puzzle neu starten';

  @override
  String get next => 'Weiter';

  @override
  String get savedCorrupt =>
      'Der gespeicherte Spielstand war beschädigt; teilweise geladen';

  @override
  String get menuBughouse => 'Bughouse';

  @override
  String get bugMode => 'Modus';

  @override
  String get bugHotSeat => 'Hot-Seat (4 Spieler)';

  @override
  String get bugVsAi => 'gegen Computer';

  @override
  String get bugYourSeat => 'Dein Platz';

  @override
  String get bugBoardA => 'Brett A';

  @override
  String get bugBoardB => 'Brett B';

  @override
  String get bugWhite => 'Weiß';

  @override
  String get bugBlack => 'Schwarz';

  @override
  String bugTeamWins(String team) {
    return 'Team $team gewinnt';
  }

  @override
  String get bugStart => 'Partie starten';

  @override
  String get bugLan => 'LAN';

  @override
  String get bugHostMatch => 'Partie hosten';

  @override
  String get bugJoinMatch => 'Partie beitreten';

  @override
  String get bugWaitingHost => 'Warten, bis der Host startet…';

  @override
  String get bugPlayersJoined => 'Beigetretene Spieler';

  @override
  String get bugAssignSeats => 'Die vier Plätze zuweisen';

  @override
  String get bugSeatHost => 'Host (du)';

  @override
  String get variant => 'Variante';

  @override
  String get vStandard => 'Standard';

  @override
  String get vThreeCheck => 'Dreischach';

  @override
  String get vKingOfTheHill => 'King of the Hill';

  @override
  String get vChess960 => 'Chess960';

  @override
  String get vAtomic => 'Atomschach';

  @override
  String get vCrazyhouse => 'Crazyhouse';

  @override
  String get vFogOfWar => 'Dark Chess';

  @override
  String get menuFourPlayer => '4 Spieler';

  @override
  String get fourFormat => 'Format';

  @override
  String get fourFFA => 'Jeder gegen jeden';

  @override
  String get fourTeams => 'Teams (2 gegen 2)';

  @override
  String get fourVsBots => 'gegen Bots';

  @override
  String get fourYourSeats => 'Deine Plätze';

  @override
  String get fourRed => 'Rot';

  @override
  String get fourBlue => 'Blau';

  @override
  String get fourYellow => 'Gelb';

  @override
  String get fourGreen => 'Grün';

  @override
  String fourTeamWins(String team) {
    return '$team gewinnt';
  }

  @override
  String fourWins(String player) {
    return '$player gewinnt';
  }

  @override
  String fogPassDevice(String color) {
    return 'Gib das Gerät an $color weiter';
  }

  @override
  String get fogTapReveal => 'Tippen, um deinen Zug aufzudecken';

  @override
  String get checksLabel => 'Schachgebote';

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
