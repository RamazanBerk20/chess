// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Шахматы';

  @override
  String get menuSinglePlayer => 'Одиночная игра';

  @override
  String get menuTwoPlayers => 'На двоих';

  @override
  String get menuLan => 'Игра по локальной сети';

  @override
  String get menuPuzzles => 'Задачи';

  @override
  String get menuResume => 'Продолжить игру';

  @override
  String get menuSettings => 'Настройки';

  @override
  String get menuPlayFromPosition => 'Игра с позиции';

  @override
  String get ok => 'ОК';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get rename => 'Переименовать';

  @override
  String get close => 'Закрыть';

  @override
  String get retry => 'Повторить';

  @override
  String get copy => 'Копировать';

  @override
  String get share => 'Поделиться';

  @override
  String get start => 'Начать';

  @override
  String get accept => 'Принять';

  @override
  String get decline => 'Отклонить';

  @override
  String get send => 'Отправить';

  @override
  String get whiteToMove => 'Ход белых';

  @override
  String get blackToMove => 'Ход чёрных';

  @override
  String get whiteToMoveCheck => 'Ход белых — шах!';

  @override
  String get blackToMoveCheck => 'Ход чёрных — шах!';

  @override
  String get checkmateWhiteWins => 'Мат — победа белых';

  @override
  String get checkmateBlackWins => 'Мат — победа чёрных';

  @override
  String get whiteWinsOnTime => 'Белые выигрывают по времени';

  @override
  String get blackWinsOnTime => 'Чёрные выигрывают по времени';

  @override
  String get drawStalemate => 'Ничья — пат';

  @override
  String get drawFiftyMove => 'Ничья — правило пятидесяти ходов';

  @override
  String get drawThreefold => 'Ничья — троекратное повторение позиции';

  @override
  String get drawInsufficient => 'Ничья — недостаточно материала';

  @override
  String get resign => 'Сдаться';

  @override
  String get offerDraw => 'Предложить ничью';

  @override
  String get drawOfferTitle => 'Предложение ничьей';

  @override
  String get drawOfferBody => 'Соперник предлагает ничью.';

  @override
  String get takeBack => 'Вернуть ход';

  @override
  String get newGame => 'Новая партия';

  @override
  String get mainMenu => 'Главное меню';

  @override
  String get flipBoard => 'Перевернуть доску';

  @override
  String get autoFlipOn => 'Автоповорот: вкл.';

  @override
  String get autoFlipOff => 'Автоповорот: выкл.';

  @override
  String get saveGame => 'Сохранить партию';

  @override
  String get aiMove => 'Ход ИИ (текущая сторона)';

  @override
  String get playAgain => 'Играть снова';

  @override
  String get analyzeGame => 'Анализировать партию';

  @override
  String get gameSaved => 'Партия сохранена';

  @override
  String get boardDesync => 'Рассинхронизация доски — партия прервана';

  @override
  String get youResigned => 'Вы сдались — поражение';

  @override
  String get opponentResigned => 'Соперник сдался — победа';

  @override
  String get drawAgreed => 'Ничья по соглашению';

  @override
  String get opponentDisconnected => 'Соперник отключился';

  @override
  String get name => 'Имя';

  @override
  String get gameName => 'Название партии';

  @override
  String get myGame => 'Моя партия';

  @override
  String get analysis => 'Анализ';

  @override
  String get white => 'Белые';

  @override
  String get black => 'Чёрные';

  @override
  String get accuracy => 'точность';

  @override
  String analyzingProgress(Object done, Object total) {
    return 'Анализ $done/$total…';
  }

  @override
  String get preparingAnalysis => 'Подготовка анализа…';

  @override
  String get clsBrilliant => 'Блестяще';

  @override
  String get clsGreat => 'Отлично';

  @override
  String get clsBest => 'Лучший ход';

  @override
  String get clsGood => 'Хорошо';

  @override
  String get clsBook => 'По дебюту';

  @override
  String get clsInaccuracy => 'Неточность';

  @override
  String get clsMiss => 'Упущение';

  @override
  String get clsMistake => 'Ошибка';

  @override
  String get clsBlunder => 'Грубая ошибка';

  @override
  String get coachBrilliant => 'Блестяще — выигрывающая жертва.';

  @override
  String get coachGreat => 'Отлично — единственный ход, удерживающий позицию.';

  @override
  String get coachBest => 'Лучший ход.';

  @override
  String get coachBook => 'Известный дебютный ход.';

  @override
  String get coachGood => 'Хороший ход.';

  @override
  String coachInaccuracy(Object best) {
    return 'Неточность — $best был немного лучше.';
  }

  @override
  String coachMiss(Object best) {
    return 'Упущен выигрывающий шанс — $best был намного сильнее.';
  }

  @override
  String coachMistake(Object best) {
    return 'Ошибка — $best был сильнее.';
  }

  @override
  String coachBlunder(Object best) {
    return 'Грубая ошибка — $best был намного лучше.';
  }

  @override
  String get settings => 'Настройки';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get boardThemeLabel => 'Тема доски';

  @override
  String get theme => 'Тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Системный по умолчанию';

  @override
  String get accessibility => 'Специальные возможности';

  @override
  String get highContrast => 'Контрастная доска';

  @override
  String get colorblindSafe => 'Цвета ходов для дальтоников';

  @override
  String get textSize => 'Размер текста';

  @override
  String get gameplay => 'Игровой процесс';

  @override
  String get sound => 'Звук';

  @override
  String get moveHints => 'Подсказки ходов';

  @override
  String get haptics => 'Вибрация';

  @override
  String get animationSpeed => 'Скорость анимации';

  @override
  String get defaultTimeControl => 'Контроль времени по умолчанию';

  @override
  String get defaultDifficulty => 'Сложность по умолчанию';

  @override
  String get hostGame => 'Создать игру';

  @override
  String get joinGame => 'Присоединиться к игре';

  @override
  String get yourName => 'Ваше имя';

  @override
  String get yourColour => 'Ваш цвет';

  @override
  String get colourWhite => 'Белые';

  @override
  String get colourBlack => 'Чёрные';

  @override
  String get colourRandom => 'Случайный';

  @override
  String get hostAGame => 'Создать игру';

  @override
  String get joinOnNetwork => 'Присоединиться к игре в этой сети';

  @override
  String get searchingHosts => 'Поиск хостов…';

  @override
  String get waitingOpponent => 'Ожидание подключения соперника…';

  @override
  String get lanGame => 'Игра по локальной сети';

  @override
  String get chat => 'Чат';

  @override
  String get typeMessage => 'Введите сообщение…';

  @override
  String get savedGames => 'Сохранённые партии';

  @override
  String get noSavedGames => 'Пока нет сохранённых партий';

  @override
  String get resume => 'Продолжить';

  @override
  String get renameGameTitle => 'Переименовать партию';

  @override
  String get playFromPosition => 'Игра с позиции';

  @override
  String get pasteFen => 'Вставьте строку FEN';

  @override
  String get fenHint =>
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  String get invalidFen => 'Некорректный FEN — проверьте строку позиции';

  @override
  String get useStartPosition => 'Использовать начальную позицию';

  @override
  String get loadPosition => 'Загрузить позицию';

  @override
  String get sideToPlay => 'Очередь хода задаётся строкой FEN';

  @override
  String get exportPgn => 'Экспорт PGN';

  @override
  String get copyPgn => 'Копировать PGN';

  @override
  String get copyMoves => 'Копировать ходы';

  @override
  String get copiedToClipboard => 'Скопировано в буфер обмена';

  @override
  String get game => 'Партия';

  @override
  String get singlePlayerTitle => 'Один игрок против ИИ';

  @override
  String get twoPlayerTitle => 'Два игрока — одно устройство';

  @override
  String get lanTitle => 'Два игрока — локальная сеть';

  @override
  String get playAs => 'Играть за';

  @override
  String get difficulty => 'Сложность';

  @override
  String get timeControl => 'Контроль времени';

  @override
  String get startGame => 'Начать партию';

  @override
  String get custom => 'Свой';

  @override
  String get tcInfinite => 'Без ограничения';

  @override
  String get diffBeginner => 'Новичок';

  @override
  String get diffEasy => 'Лёгкий';

  @override
  String get diffMedium => 'Средний';

  @override
  String get diffHard => 'Сложный';

  @override
  String get diffExpert => 'Эксперт';

  @override
  String get baseMinutes => 'Основное время (минуты)';

  @override
  String get incrementSeconds => 'Добавление (секунды)';

  @override
  String get baseTimeError => 'Основное время должно быть не менее 1 минуты';

  @override
  String get searchDepth => 'Глубина расчёта';

  @override
  String get timePerMove => 'Время на ход (мс)';

  @override
  String get topNRandom => 'Случайный из топ-N';

  @override
  String get blunderChance => 'Шанс зевка';

  @override
  String get evalNoise => 'Шум оценки (сантипешки)';

  @override
  String puzzlesSolved(Object solved, Object total) {
    return 'Решено $solved/$total';
  }

  @override
  String get alreadySolved => 'уже решено';

  @override
  String get puzzleWrong => 'Не тот ход — попробуйте снова';

  @override
  String get puzzleSolvedMsg => 'Решено! ✓  Нажмите ▶ для следующей задачи';

  @override
  String puzzleFooter(
    Object index,
    Object total,
    Object rating,
    Object streak,
    Object best,
  ) {
    return 'Задача $index/$total  ·  рейтинг $rating  ·  серия $streak (рекорд $best)';
  }

  @override
  String get loadPuzzlesFailed => 'Не удалось загрузить задачи';

  @override
  String get previous => 'Назад';

  @override
  String get hint => 'Подсказка';

  @override
  String get restartPuzzle => 'Заново';

  @override
  String get next => 'Далее';

  @override
  String get savedCorrupt =>
      'Сохранённая партия повреждена; загружена частично';

  @override
  String get menuBughouse => 'Багхаус';

  @override
  String get bugMode => 'Режим';

  @override
  String get bugHotSeat => 'За одним устройством (4 игрока)';

  @override
  String get bugVsAi => 'Против компьютера';

  @override
  String get bugYourSeat => 'Ваше место';

  @override
  String get bugBoardA => 'Доска A';

  @override
  String get bugBoardB => 'Доска B';

  @override
  String get bugWhite => 'Белые';

  @override
  String get bugBlack => 'Чёрные';

  @override
  String bugTeamWins(String team) {
    return 'Команда $team побеждает';
  }

  @override
  String get bugStart => 'Начать матч';

  @override
  String get bugLan => 'Локальная сеть';

  @override
  String get bugHostMatch => 'Создать матч';

  @override
  String get bugJoinMatch => 'Присоединиться к матчу';

  @override
  String get bugWaitingHost => 'Ожидание начала матча хостом…';

  @override
  String get bugPlayersJoined => 'Игроков присоединилось';

  @override
  String get bugAssignSeats => 'Распределите четыре места';

  @override
  String get bugSeatHost => 'Хост (вы)';

  @override
  String get variant => 'Вариант';

  @override
  String get vStandard => 'Стандартные';

  @override
  String get vThreeCheck => 'Три шаха';

  @override
  String get vKingOfTheHill => 'Король горы';

  @override
  String get vChess960 => 'Шахматы 960';

  @override
  String get vAtomic => 'Атомные шахматы';

  @override
  String get vCrazyhouse => 'Крейзихаус';

  @override
  String get vFogOfWar => 'Тёмные шахматы';

  @override
  String get menuFourPlayer => '4 игрока';

  @override
  String get fourFormat => 'Формат';

  @override
  String get fourFFA => 'Каждый сам за себя';

  @override
  String get fourTeams => 'Команды (2 на 2)';

  @override
  String get fourVsBots => 'Против ботов';

  @override
  String get fourYourSeats => 'Ваши места';

  @override
  String get fourRed => 'Красные';

  @override
  String get fourBlue => 'Синие';

  @override
  String get fourYellow => 'Жёлтые';

  @override
  String get fourGreen => 'Зелёные';

  @override
  String fourTeamWins(String team) {
    return '$team побеждает';
  }

  @override
  String fourWins(String player) {
    return '$player побеждает';
  }

  @override
  String fogPassDevice(String color) {
    return 'Передайте устройство игроку $color';
  }

  @override
  String get fogTapReveal => 'Нажмите, чтобы открыть свой ход';

  @override
  String get checksLabel => 'Шахи';

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
