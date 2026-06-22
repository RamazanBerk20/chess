// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '国际象棋';

  @override
  String get menuSinglePlayer => '单人对战';

  @override
  String get menuTwoPlayers => '双人对战';

  @override
  String get menuLan => '局域网对战';

  @override
  String get menuPuzzles => '战术题';

  @override
  String get menuResume => '继续对局';

  @override
  String get menuSettings => '设置';

  @override
  String get menuPlayFromPosition => '从指定局面开始';

  @override
  String get ok => '确定';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get rename => '重命名';

  @override
  String get close => '关闭';

  @override
  String get retry => '重试';

  @override
  String get copy => '复制';

  @override
  String get share => '分享';

  @override
  String get start => '开始';

  @override
  String get accept => '接受';

  @override
  String get decline => '拒绝';

  @override
  String get send => '发送';

  @override
  String get whiteToMove => '轮到白方走棋';

  @override
  String get blackToMove => '轮到黑方走棋';

  @override
  String get whiteToMoveCheck => '轮到白方走棋 — 将军！';

  @override
  String get blackToMoveCheck => '轮到黑方走棋 — 将军！';

  @override
  String get checkmateWhiteWins => '将死 — 白方获胜';

  @override
  String get checkmateBlackWins => '将死 — 黑方获胜';

  @override
  String get whiteWinsOnTime => '白方超时获胜';

  @override
  String get blackWinsOnTime => '黑方超时获胜';

  @override
  String get drawStalemate => '和棋 — 逼和';

  @override
  String get drawFiftyMove => '和棋 — 五十回合规则';

  @override
  String get drawThreefold => '和棋 — 三次重复局面';

  @override
  String get drawInsufficient => '和棋 — 子力不足';

  @override
  String get resign => '认输';

  @override
  String get offerDraw => '提和';

  @override
  String get drawOfferTitle => '提和请求';

  @override
  String get drawOfferBody => '对手向你提和。';

  @override
  String get takeBack => '悔棋';

  @override
  String get newGame => '新对局';

  @override
  String get mainMenu => '主菜单';

  @override
  String get flipBoard => '翻转棋盘';

  @override
  String get autoFlipOn => '自动翻转：开';

  @override
  String get autoFlipOff => '自动翻转：关';

  @override
  String get saveGame => '保存对局';

  @override
  String get aiMove => 'AI走棋（当前一方）';

  @override
  String get playAgain => '再来一局';

  @override
  String get analyzeGame => '分析对局';

  @override
  String get gameSaved => '对局已保存';

  @override
  String get boardDesync => '棋盘不同步 — 对局已中止';

  @override
  String get youResigned => '你已认输 — 你输了';

  @override
  String get opponentResigned => '对手认输 — 你赢了';

  @override
  String get drawAgreed => '双方同意和棋';

  @override
  String get opponentDisconnected => '对手已断开连接';

  @override
  String get name => '名称';

  @override
  String get gameName => '对局名称';

  @override
  String get myGame => '我的对局';

  @override
  String get analysis => '分析';

  @override
  String get white => '白方';

  @override
  String get black => '黑方';

  @override
  String get accuracy => '准确率';

  @override
  String analyzingProgress(Object done, Object total) {
    return '正在分析 $done/$total…';
  }

  @override
  String get preparingAnalysis => '正在准备分析…';

  @override
  String get clsBrilliant => '妙手';

  @override
  String get clsGreat => '精彩';

  @override
  String get clsBest => '最佳';

  @override
  String get clsGood => '良好';

  @override
  String get clsBook => '定式';

  @override
  String get clsInaccuracy => '不精确';

  @override
  String get clsMiss => '错失';

  @override
  String get clsMistake => '失误';

  @override
  String get clsBlunder => '漏着';

  @override
  String get coachBrilliant => '妙手 — 制胜的弃子。';

  @override
  String get coachGreat => '精彩 — 唯一能守住的一手。';

  @override
  String get coachBest => '最佳着法。';

  @override
  String get coachBook => '已知的开局着法。';

  @override
  String get coachGood => '不错的一手。';

  @override
  String coachInaccuracy(Object best) {
    return '不精确 — $best 会稍好一些。';
  }

  @override
  String coachMiss(Object best) {
    return '错失制胜良机 — $best 要强得多。';
  }

  @override
  String coachMistake(Object best) {
    return '失误 — $best 更强。';
  }

  @override
  String coachBlunder(Object best) {
    return '漏着 — $best 要好得多。';
  }

  @override
  String get settings => '设置';

  @override
  String get appearance => '外观';

  @override
  String get boardThemeLabel => '棋盘主题';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '系统默认';

  @override
  String get accessibility => '无障碍';

  @override
  String get highContrast => '高对比度棋盘';

  @override
  String get colorblindSafe => '色盲友好的走法颜色';

  @override
  String get textSize => '文字大小';

  @override
  String get gameplay => '玩法';

  @override
  String get sound => '音效';

  @override
  String get moveHints => '走法提示';

  @override
  String get haptics => '触感反馈';

  @override
  String get animationSpeed => '动画速度';

  @override
  String get defaultTimeControl => '默认时间控制';

  @override
  String get defaultDifficulty => '默认难度';

  @override
  String get hostGame => '创建对局';

  @override
  String get joinGame => '加入对局';

  @override
  String get yourName => '你的名字';

  @override
  String get yourColour => '你的执棋方';

  @override
  String get colourWhite => '白方';

  @override
  String get colourBlack => '黑方';

  @override
  String get colourRandom => '随机';

  @override
  String get hostAGame => '创建一局对战';

  @override
  String get joinOnNetwork => '加入本网络中的对局';

  @override
  String get searchingHosts => '正在搜索主机…';

  @override
  String get waitingOpponent => '正在等待对手连接…';

  @override
  String get lanGame => '局域网对局';

  @override
  String get chat => '聊天';

  @override
  String get typeMessage => '输入消息…';

  @override
  String get savedGames => '已保存的对局';

  @override
  String get noSavedGames => '暂无已保存的对局';

  @override
  String get resume => '继续';

  @override
  String get renameGameTitle => '重命名对局';

  @override
  String get playFromPosition => '从指定局面开始';

  @override
  String get pasteFen => '粘贴 FEN 字符串';

  @override
  String get fenHint =>
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  String get invalidFen => '无效的 FEN — 请检查局面字符串';

  @override
  String get useStartPosition => '使用初始局面';

  @override
  String get loadPosition => '加载局面';

  @override
  String get sideToPlay => '走棋方由 FEN 决定';

  @override
  String get exportPgn => '导出 PGN';

  @override
  String get copyPgn => '复制 PGN';

  @override
  String get copyMoves => '复制着法';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get game => '对局';

  @override
  String get singlePlayerTitle => '单人对战 AI';

  @override
  String get twoPlayerTitle => '双人对战 — 同一设备';

  @override
  String get lanTitle => '双人对战 — 局域网';

  @override
  String get playAs => '执子';

  @override
  String get difficulty => '难度';

  @override
  String get timeControl => '时间控制';

  @override
  String get startGame => '开始对局';

  @override
  String get custom => '自定义';

  @override
  String get tcInfinite => '无限制';

  @override
  String get diffBeginner => '初学者';

  @override
  String get diffEasy => '简单';

  @override
  String get diffMedium => '中等';

  @override
  String get diffHard => '困难';

  @override
  String get diffExpert => '专家';

  @override
  String get baseMinutes => '基础时间（分钟）';

  @override
  String get incrementSeconds => '加秒（秒）';

  @override
  String get baseTimeError => '基础时间至少为 1 分钟';

  @override
  String get searchDepth => '搜索深度';

  @override
  String get timePerMove => '每步用时（毫秒）';

  @override
  String get topNRandom => '前 N 随机';

  @override
  String get blunderChance => '漏着概率';

  @override
  String get evalNoise => '评估噪声（cp）';

  @override
  String puzzlesSolved(Object solved, Object total) {
    return '已解 $solved/$total';
  }

  @override
  String get alreadySolved => '已解出';

  @override
  String get puzzleWrong => '不是这一步 — 请再试一次';

  @override
  String get puzzleSolvedMsg => '解出！✓  点击 ▶ 进入下一题';

  @override
  String puzzleFooter(
    Object index,
    Object total,
    Object rating,
    Object streak,
    Object best,
  ) {
    return '残局 $index/$total  ·  等级分 $rating  ·  连胜 $streak（最佳 $best）';
  }

  @override
  String get loadPuzzlesFailed => '加载残局失败';

  @override
  String get previous => '上一个';

  @override
  String get hint => '提示';

  @override
  String get restartPuzzle => '重新开始残局';

  @override
  String get next => '下一个';

  @override
  String get savedCorrupt => '存档已损坏；已部分加载';

  @override
  String get menuBughouse => '双人换子棋';

  @override
  String get bugMode => '模式';

  @override
  String get bugHotSeat => '同屏对战（4人）';

  @override
  String get bugVsAi => '对战电脑';

  @override
  String get bugYourSeat => '你的座位';

  @override
  String get bugBoardA => '棋盘A';

  @override
  String get bugBoardB => '棋盘B';

  @override
  String get bugWhite => '白方';

  @override
  String get bugBlack => '黑方';

  @override
  String bugTeamWins(String team) {
    return '$team队获胜';
  }

  @override
  String get bugStart => '开始对局';

  @override
  String get bugLan => '局域网';

  @override
  String get bugHostMatch => '创建对局';

  @override
  String get bugJoinMatch => '加入对局';

  @override
  String get bugWaitingHost => '正在等待房主开始…';

  @override
  String get bugPlayersJoined => '已加入玩家';

  @override
  String get bugAssignSeats => '分配四个座位';

  @override
  String get bugSeatHost => '房主（你）';

  @override
  String get variant => '变体';

  @override
  String get vStandard => '标准';

  @override
  String get vThreeCheck => '三次将军';

  @override
  String get vKingOfTheHill => '占山为王';

  @override
  String get vChess960 => '国际象棋960';

  @override
  String get vAtomic => '原子象棋';

  @override
  String get vCrazyhouse => '疯狂屋';

  @override
  String get vFogOfWar => '黑暗棋';

  @override
  String get menuFourPlayer => '四人';

  @override
  String get fourFormat => '模式';

  @override
  String get fourFFA => '混战';

  @override
  String get fourTeams => '组队（2v2）';

  @override
  String get fourVsBots => '对战电脑';

  @override
  String get fourYourSeats => '你的座位';

  @override
  String get fourRed => '红方';

  @override
  String get fourBlue => '蓝方';

  @override
  String get fourYellow => '黄方';

  @override
  String get fourGreen => '绿方';

  @override
  String fourTeamWins(String team) {
    return '$team获胜';
  }

  @override
  String fourWins(String player) {
    return '$player获胜';
  }

  @override
  String fogPassDevice(String color) {
    return '请将设备交给$color';
  }

  @override
  String get fogTapReveal => '点击屏幕显示你的回合';

  @override
  String get checksLabel => '将军次数';

  @override
  String get support => '支持';

  @override
  String get donate => '捐赠';

  @override
  String get donateSubtitle => '通过 GitHub Sponsors 支持开发';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get checkingForUpdates => '正在检查更新…';

  @override
  String get upToDate => '您使用的是最新版本。';

  @override
  String get updateAvailable => '有可用更新';

  @override
  String get newVersionAvailable => '有新版本可用：';

  @override
  String get download => '下载';

  @override
  String get later => '稍后';

  @override
  String get about => '关于';
}
