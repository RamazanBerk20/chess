// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'شطرنج';

  @override
  String get menuSinglePlayer => 'لاعب واحد';

  @override
  String get menuTwoPlayers => 'لاعبان';

  @override
  String get menuLan => 'اللعب عبر الشبكة المحلية';

  @override
  String get menuPuzzles => 'الألغاز';

  @override
  String get menuResume => 'استئناف اللعبة';

  @override
  String get menuSettings => 'الإعدادات';

  @override
  String get menuPlayFromPosition => 'اللعب من وضعية';

  @override
  String get ok => 'موافق';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get delete => 'حذف';

  @override
  String get rename => 'إعادة تسمية';

  @override
  String get close => 'إغلاق';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get copy => 'نسخ';

  @override
  String get share => 'مشاركة';

  @override
  String get start => 'ابدأ';

  @override
  String get accept => 'قبول';

  @override
  String get decline => 'رفض';

  @override
  String get send => 'إرسال';

  @override
  String get whiteToMove => 'دور الأبيض';

  @override
  String get blackToMove => 'دور الأسود';

  @override
  String get whiteToMoveCheck => 'دور الأبيض — كش!';

  @override
  String get blackToMoveCheck => 'دور الأسود — كش!';

  @override
  String get checkmateWhiteWins => 'كش مات — الأبيض يفوز';

  @override
  String get checkmateBlackWins => 'كش مات — الأسود يفوز';

  @override
  String get whiteWinsOnTime => 'الأبيض يفوز بانتهاء الوقت';

  @override
  String get blackWinsOnTime => 'الأسود يفوز بانتهاء الوقت';

  @override
  String get drawStalemate => 'تعادل — جمود';

  @override
  String get drawFiftyMove => 'تعادل — قاعدة الخمسين نقلة';

  @override
  String get drawThreefold => 'تعادل — تكرار الوضعية ثلاث مرات';

  @override
  String get drawInsufficient => 'تعادل — عدم كفاية القطع';

  @override
  String get resign => 'الاستسلام';

  @override
  String get offerDraw => 'عرض التعادل';

  @override
  String get drawOfferTitle => 'عرض تعادل';

  @override
  String get drawOfferBody => 'خصمك يعرض التعادل.';

  @override
  String get takeBack => 'التراجع عن النقلة';

  @override
  String get newGame => 'لعبة جديدة';

  @override
  String get mainMenu => 'القائمة الرئيسية';

  @override
  String get flipBoard => 'قلب الرقعة';

  @override
  String get autoFlipOn => 'القلب التلقائي: مفعّل';

  @override
  String get autoFlipOff => 'القلب التلقائي: معطّل';

  @override
  String get saveGame => 'حفظ اللعبة';

  @override
  String get aiMove => 'نقلة الذكاء الاصطناعي (الجانب الحالي)';

  @override
  String get playAgain => 'العب مرة أخرى';

  @override
  String get analyzeGame => 'تحليل اللعبة';

  @override
  String get gameSaved => 'تم حفظ اللعبة';

  @override
  String get boardDesync => 'عدم تزامن الرقعة — تم إيقاف اللعبة';

  @override
  String get youResigned => 'لقد استسلمت — أنت خاسر';

  @override
  String get opponentResigned => 'استسلم الخصم — أنت الفائز';

  @override
  String get drawAgreed => 'تم الاتفاق على التعادل';

  @override
  String get opponentDisconnected => 'انقطع اتصال الخصم';

  @override
  String get name => 'الاسم';

  @override
  String get gameName => 'اسم اللعبة';

  @override
  String get myGame => 'لعبتي';

  @override
  String get analysis => 'التحليل';

  @override
  String get white => 'الأبيض';

  @override
  String get black => 'الأسود';

  @override
  String get accuracy => 'الدقة';

  @override
  String analyzingProgress(Object done, Object total) {
    return 'جارٍ التحليل $done/$total…';
  }

  @override
  String get preparingAnalysis => 'جارٍ تحضير التحليل…';

  @override
  String get clsBrilliant => 'نقلة رائعة';

  @override
  String get clsGreat => 'نقلة عظيمة';

  @override
  String get clsBest => 'أفضل نقلة';

  @override
  String get clsGood => 'نقلة جيدة';

  @override
  String get clsBook => 'نقلة معروفة';

  @override
  String get clsInaccuracy => 'نقلة غير دقيقة';

  @override
  String get clsMiss => 'فرصة ضائعة';

  @override
  String get clsMistake => 'خطأ';

  @override
  String get clsBlunder => 'خطأ فادح';

  @override
  String get coachBrilliant => 'نقلة رائعة — تضحية رابحة.';

  @override
  String get coachGreat => 'نقلة عظيمة — النقلة الوحيدة التي تصمد.';

  @override
  String get coachBest => 'أفضل نقلة.';

  @override
  String get coachBook => 'نقلة افتتاحية معروفة.';

  @override
  String get coachGood => 'نقلة جيدة.';

  @override
  String coachInaccuracy(Object best) {
    return 'نقلة غير دقيقة — كانت $best أفضل قليلاً.';
  }

  @override
  String coachMiss(Object best) {
    return 'فرصة رابحة ضائعة — كانت $best أقوى بكثير.';
  }

  @override
  String coachMistake(Object best) {
    return 'خطأ — كانت $best أقوى.';
  }

  @override
  String coachBlunder(Object best) {
    return 'خطأ فادح — كانت $best أفضل بكثير.';
  }

  @override
  String get settings => 'الإعدادات';

  @override
  String get appearance => 'المظهر';

  @override
  String get boardThemeLabel => 'سمة الرقعة';

  @override
  String get theme => 'السمة';

  @override
  String get themeSystem => 'النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get language => 'اللغة';

  @override
  String get languageSystem => 'افتراضي النظام';

  @override
  String get accessibility => 'إمكانية الوصول';

  @override
  String get highContrast => 'رقعة عالية التباين';

  @override
  String get colorblindSafe => 'ألوان نقلات مناسبة لعمى الألوان';

  @override
  String get textSize => 'حجم النص';

  @override
  String get gameplay => 'طريقة اللعب';

  @override
  String get sound => 'الصوت';

  @override
  String get moveHints => 'تلميحات النقلات';

  @override
  String get haptics => 'الاهتزاز اللمسي';

  @override
  String get animationSpeed => 'سرعة الحركة';

  @override
  String get defaultTimeControl => 'التحكم الافتراضي بالوقت';

  @override
  String get defaultDifficulty => 'مستوى الصعوبة الافتراضي';

  @override
  String get hostGame => 'استضافة لعبة';

  @override
  String get joinGame => 'الانضمام إلى لعبة';

  @override
  String get yourName => 'اسمك';

  @override
  String get yourColour => 'لونك';

  @override
  String get colourWhite => 'الأبيض';

  @override
  String get colourBlack => 'الأسود';

  @override
  String get colourRandom => 'عشوائي';

  @override
  String get hostAGame => 'استضف لعبة';

  @override
  String get joinOnNetwork => 'انضم إلى لعبة على هذه الشبكة';

  @override
  String get searchingHosts => 'جارٍ البحث عن المضيفين…';

  @override
  String get waitingOpponent => 'في انتظار اتصال خصم…';

  @override
  String get lanGame => 'لعبة عبر الشبكة المحلية';

  @override
  String get chat => 'الدردشة';

  @override
  String get typeMessage => 'اكتب رسالة…';

  @override
  String get savedGames => 'الألعاب المحفوظة';

  @override
  String get noSavedGames => 'لا توجد ألعاب محفوظة بعد';

  @override
  String get resume => 'استئناف';

  @override
  String get renameGameTitle => 'إعادة تسمية اللعبة';

  @override
  String get playFromPosition => 'اللعب من وضعية';

  @override
  String get pasteFen => 'الصق سلسلة FEN';

  @override
  String get fenHint =>
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  String get invalidFen => 'سلسلة FEN غير صالحة — تحقق من سلسلة الوضعية';

  @override
  String get useStartPosition => 'استخدام وضعية البداية';

  @override
  String get loadPosition => 'تحميل الوضعية';

  @override
  String get sideToPlay => 'يُحدَّد الجانب صاحب الدور بواسطة سلسلة FEN';

  @override
  String get exportPgn => 'تصدير PGN';

  @override
  String get copyPgn => 'نسخ PGN';

  @override
  String get copyMoves => 'نسخ النقلات';

  @override
  String get copiedToClipboard => 'تم النسخ إلى الحافظة';

  @override
  String get game => 'اللعبة';

  @override
  String get singlePlayerTitle => 'لاعب واحد ضد الذكاء الاصطناعي';

  @override
  String get twoPlayerTitle => 'لاعبان — الجهاز نفسه';

  @override
  String get lanTitle => 'لاعبان — الشبكة المحلية';

  @override
  String get playAs => 'اللعب بـ';

  @override
  String get difficulty => 'الصعوبة';

  @override
  String get timeControl => 'التحكم بالوقت';

  @override
  String get startGame => 'بدء اللعبة';

  @override
  String get custom => 'مخصص';

  @override
  String get tcInfinite => 'غير محدود';

  @override
  String get diffBeginner => 'مبتدئ';

  @override
  String get diffEasy => 'سهل';

  @override
  String get diffMedium => 'متوسط';

  @override
  String get diffHard => 'صعب';

  @override
  String get diffExpert => 'خبير';

  @override
  String get baseMinutes => 'الدقائق الأساسية';

  @override
  String get incrementSeconds => 'ثواني الزيادة';

  @override
  String get baseTimeError => 'يجب ألا يقل الوقت الأساسي عن دقيقة واحدة';

  @override
  String get searchDepth => 'عمق البحث';

  @override
  String get timePerMove => 'الوقت/النقلة (مللي ثانية)';

  @override
  String get topNRandom => 'عشوائي من أفضل N';

  @override
  String get blunderChance => 'احتمال الخطأ الفادح';

  @override
  String get evalNoise => 'تشويش التقييم (سم)';

  @override
  String puzzlesSolved(Object solved, Object total) {
    return 'تم حل $solved/$total';
  }

  @override
  String get alreadySolved => 'تم حله مسبقاً';

  @override
  String get puzzleWrong => 'ليست النقلة الصحيحة — حاول مجدداً';

  @override
  String get puzzleSolvedMsg => 'تم الحل! ✓  انقر ▶ للأحجية التالية';

  @override
  String puzzleFooter(
    Object index,
    Object total,
    Object rating,
    Object streak,
    Object best,
  ) {
    return 'الأحجية $index/$total  ·  التصنيف $rating  ·  السلسلة $streak (الأفضل $best)';
  }

  @override
  String get loadPuzzlesFailed => 'فشل تحميل الأحجيات';

  @override
  String get previous => 'السابق';

  @override
  String get hint => 'تلميح';

  @override
  String get restartPuzzle => 'إعادة الأحجية';

  @override
  String get next => 'التالي';

  @override
  String get savedCorrupt => 'كانت اللعبة المحفوظة تالفة؛ تم تحميلها جزئياً';

  @override
  String get menuBughouse => 'باغهاوس';

  @override
  String get bugMode => 'الوضع';

  @override
  String get bugHotSeat => 'المقعد المشترك (٤ لاعبين)';

  @override
  String get bugVsAi => 'ضد الحاسوب';

  @override
  String get bugYourSeat => 'مقعدك';

  @override
  String get bugBoardA => 'الرقعة أ';

  @override
  String get bugBoardB => 'الرقعة ب';

  @override
  String get bugWhite => 'الأبيض';

  @override
  String get bugBlack => 'الأسود';

  @override
  String bugTeamWins(String team) {
    return 'فوز الفريق $team';
  }

  @override
  String get bugStart => 'ابدأ المباراة';

  @override
  String get bugLan => 'الشبكة المحلية';

  @override
  String get bugHostMatch => 'استضافة مباراة';

  @override
  String get bugJoinMatch => 'الانضمام إلى مباراة';

  @override
  String get bugWaitingHost => 'في انتظار المضيف لبدء المباراة…';

  @override
  String get bugPlayersJoined => 'اللاعبون المنضمّون';

  @override
  String get bugAssignSeats => 'توزيع المقاعد الأربعة';

  @override
  String get bugSeatHost => 'المضيف (أنت)';

  @override
  String get variant => 'النوع';

  @override
  String get vStandard => 'الكلاسيكية';

  @override
  String get vThreeCheck => 'الكشوف الثلاثة';

  @override
  String get vKingOfTheHill => 'ملك التل';

  @override
  String get vChess960 => 'شطرنج 960';

  @override
  String get vAtomic => 'الذرية';

  @override
  String get vCrazyhouse => 'البيت المجنون';

  @override
  String get vFogOfWar => 'شطرنج الظلام';

  @override
  String get menuFourPlayer => '4 لاعبين';

  @override
  String get fourFormat => 'النمط';

  @override
  String get fourFFA => 'الكل ضد الكل';

  @override
  String get fourTeams => 'فِرَق (2 ضد 2)';

  @override
  String get fourVsBots => 'ضد الروبوتات';

  @override
  String get fourYourSeats => 'مقاعدك';

  @override
  String get fourRed => 'الأحمر';

  @override
  String get fourBlue => 'الأزرق';

  @override
  String get fourYellow => 'الأصفر';

  @override
  String get fourGreen => 'الأخضر';

  @override
  String fourTeamWins(String team) {
    return 'فوز $team';
  }

  @override
  String fourWins(String player) {
    return 'فوز $player';
  }

  @override
  String fogPassDevice(String color) {
    return 'مرّر الجهاز إلى $color';
  }

  @override
  String get fogTapReveal => 'انقر لكشف دورك';

  @override
  String get checksLabel => 'الكشوف';

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
