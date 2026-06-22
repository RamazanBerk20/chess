// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '체스';

  @override
  String get menuSinglePlayer => '1인 플레이';

  @override
  String get menuTwoPlayers => '2인 플레이';

  @override
  String get menuLan => 'LAN으로 플레이';

  @override
  String get menuPuzzles => '퍼즐';

  @override
  String get menuResume => '게임 이어하기';

  @override
  String get menuSettings => '설정';

  @override
  String get menuPlayFromPosition => '특정 국면에서 시작';

  @override
  String get ok => '확인';

  @override
  String get cancel => '취소';

  @override
  String get save => '저장';

  @override
  String get delete => '삭제';

  @override
  String get rename => '이름 변경';

  @override
  String get close => '닫기';

  @override
  String get retry => '다시 시도';

  @override
  String get copy => '복사';

  @override
  String get share => '공유';

  @override
  String get start => '시작';

  @override
  String get accept => '수락';

  @override
  String get decline => '거절';

  @override
  String get send => '보내기';

  @override
  String get whiteToMove => '백 차례';

  @override
  String get blackToMove => '흑 차례';

  @override
  String get whiteToMoveCheck => '백 차례 — 체크!';

  @override
  String get blackToMoveCheck => '흑 차례 — 체크!';

  @override
  String get checkmateWhiteWins => '체크메이트 — 백 승리';

  @override
  String get checkmateBlackWins => '체크메이트 — 흑 승리';

  @override
  String get whiteWinsOnTime => '시간 승부로 백 승리';

  @override
  String get blackWinsOnTime => '시간 승부로 흑 승리';

  @override
  String get drawStalemate => '무승부 — 스테일메이트';

  @override
  String get drawFiftyMove => '무승부 — 50수 규칙';

  @override
  String get drawThreefold => '무승부 — 동형 3회 반복';

  @override
  String get drawInsufficient => '무승부 — 기물 부족';

  @override
  String get resign => '기권';

  @override
  String get offerDraw => '무승부 제안';

  @override
  String get drawOfferTitle => '무승부 제안';

  @override
  String get drawOfferBody => '상대가 무승부를 제안했습니다.';

  @override
  String get takeBack => '무르기';

  @override
  String get newGame => '새 게임';

  @override
  String get mainMenu => '메인 메뉴';

  @override
  String get flipBoard => '보드 뒤집기';

  @override
  String get autoFlipOn => '자동 뒤집기: 켜짐';

  @override
  String get autoFlipOff => '자동 뒤집기: 꺼짐';

  @override
  String get saveGame => '게임 저장';

  @override
  String get aiMove => 'AI 착수 (현재 차례)';

  @override
  String get playAgain => '다시 플레이';

  @override
  String get analyzeGame => '게임 분석';

  @override
  String get gameSaved => '게임이 저장되었습니다';

  @override
  String get boardDesync => '보드 동기화 오류 — 게임 중단됨';

  @override
  String get youResigned => '기권했습니다 — 패배';

  @override
  String get opponentResigned => '상대가 기권했습니다 — 승리';

  @override
  String get drawAgreed => '무승부 합의';

  @override
  String get opponentDisconnected => '상대 연결이 끊어졌습니다';

  @override
  String get name => '이름';

  @override
  String get gameName => '게임 이름';

  @override
  String get myGame => '내 게임';

  @override
  String get analysis => '분석';

  @override
  String get white => '백';

  @override
  String get black => '흑';

  @override
  String get accuracy => '정확도';

  @override
  String analyzingProgress(Object done, Object total) {
    return '분석 중 $done/$total…';
  }

  @override
  String get preparingAnalysis => '분석 준비 중…';

  @override
  String get clsBrilliant => '최고의 한 수';

  @override
  String get clsGreat => '훌륭한 수';

  @override
  String get clsBest => '최선의 수';

  @override
  String get clsGood => '좋은 수';

  @override
  String get clsBook => '정석';

  @override
  String get clsInaccuracy => '부정확한 수';

  @override
  String get clsMiss => '놓친 수';

  @override
  String get clsMistake => '실수';

  @override
  String get clsBlunder => '대실수';

  @override
  String get coachBrilliant => '최고의 한 수 — 승리를 부르는 희생입니다.';

  @override
  String get coachGreat => '훌륭한 수 — 국면을 지키는 유일한 수입니다.';

  @override
  String get coachBest => '최선의 수입니다.';

  @override
  String get coachBook => '잘 알려진 오프닝 수입니다.';

  @override
  String get coachGood => '좋은 수입니다.';

  @override
  String coachInaccuracy(Object best) {
    return '부정확한 수 — $best가 조금 더 나았습니다.';
  }

  @override
  String coachMiss(Object best) {
    return '이길 기회를 놓쳤습니다 — $best가 훨씬 강했습니다.';
  }

  @override
  String coachMistake(Object best) {
    return '실수 — $best가 더 강했습니다.';
  }

  @override
  String coachBlunder(Object best) {
    return '대실수 — $best가 훨씬 나았습니다.';
  }

  @override
  String get settings => '설정';

  @override
  String get appearance => '외관';

  @override
  String get boardThemeLabel => '보드 테마';

  @override
  String get theme => '테마';

  @override
  String get themeSystem => '시스템';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get language => '언어';

  @override
  String get languageSystem => '시스템 기본값';

  @override
  String get accessibility => '접근성';

  @override
  String get highContrast => '고대비 보드';

  @override
  String get colorblindSafe => '색맹 친화 착수 색상';

  @override
  String get textSize => '글자 크기';

  @override
  String get gameplay => '게임플레이';

  @override
  String get sound => '소리';

  @override
  String get moveHints => '착수 힌트';

  @override
  String get haptics => '햅틱';

  @override
  String get animationSpeed => '애니메이션 속도';

  @override
  String get defaultTimeControl => '기본 시간 제한';

  @override
  String get defaultDifficulty => '기본 난이도';

  @override
  String get hostGame => '게임 호스트';

  @override
  String get joinGame => '게임 참가';

  @override
  String get yourName => '이름';

  @override
  String get yourColour => '당신의 색상';

  @override
  String get colourWhite => '백';

  @override
  String get colourBlack => '흑';

  @override
  String get colourRandom => '무작위';

  @override
  String get hostAGame => '게임 호스트하기';

  @override
  String get joinOnNetwork => '이 네트워크의 게임에 참가';

  @override
  String get searchingHosts => '호스트 검색 중…';

  @override
  String get waitingOpponent => '상대의 연결을 기다리는 중…';

  @override
  String get lanGame => 'LAN 게임';

  @override
  String get chat => '채팅';

  @override
  String get typeMessage => '메시지를 입력하세요…';

  @override
  String get savedGames => '저장된 게임';

  @override
  String get noSavedGames => '아직 저장된 게임이 없습니다';

  @override
  String get resume => '이어하기';

  @override
  String get renameGameTitle => '게임 이름 변경';

  @override
  String get playFromPosition => '특정 국면에서 시작';

  @override
  String get pasteFen => 'FEN 문자열을 붙여넣으세요';

  @override
  String get fenHint =>
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  String get invalidFen => '잘못된 FEN — 국면 문자열을 확인하세요';

  @override
  String get useStartPosition => '시작 국면 사용';

  @override
  String get loadPosition => '국면 불러오기';

  @override
  String get sideToPlay => '착수할 차례는 FEN에 따라 설정됩니다';

  @override
  String get exportPgn => 'PGN 내보내기';

  @override
  String get copyPgn => 'PGN 복사';

  @override
  String get copyMoves => '기보 복사';

  @override
  String get copiedToClipboard => '클립보드에 복사되었습니다';

  @override
  String get game => '게임';

  @override
  String get singlePlayerTitle => '1인용 대 AI';

  @override
  String get twoPlayerTitle => '2인용 — 같은 기기';

  @override
  String get lanTitle => '2인용 — LAN';

  @override
  String get playAs => '플레이 색상';

  @override
  String get difficulty => '난이도';

  @override
  String get timeControl => '시간 제한';

  @override
  String get startGame => '게임 시작';

  @override
  String get custom => '사용자 지정';

  @override
  String get tcInfinite => '무제한';

  @override
  String get diffBeginner => '입문';

  @override
  String get diffEasy => '쉬움';

  @override
  String get diffMedium => '보통';

  @override
  String get diffHard => '어려움';

  @override
  String get diffExpert => '전문가';

  @override
  String get baseMinutes => '기본 시간(분)';

  @override
  String get incrementSeconds => '추가 시간(초)';

  @override
  String get baseTimeError => '기본 시간은 최소 1분 이상이어야 합니다';

  @override
  String get searchDepth => '탐색 깊이';

  @override
  String get timePerMove => '수당 시간(ms)';

  @override
  String get topNRandom => '상위 N개 무작위';

  @override
  String get blunderChance => '실수 확률';

  @override
  String get evalNoise => '평가 노이즈(cp)';

  @override
  String puzzlesSolved(Object solved, Object total) {
    return '$solved/$total 해결';
  }

  @override
  String get alreadySolved => '이미 해결함';

  @override
  String get puzzleWrong => '올바른 수가 아닙니다 — 다시 시도하세요';

  @override
  String get puzzleSolvedMsg => '해결! ✓  다음 퍼즐은 ▶ 을 누르세요';

  @override
  String puzzleFooter(
    Object index,
    Object total,
    Object rating,
    Object streak,
    Object best,
  ) {
    return '퍼즐 $index/$total  ·  레이팅 $rating  ·  연속 $streak (최고 $best)';
  }

  @override
  String get loadPuzzlesFailed => '퍼즐을 불러오지 못했습니다';

  @override
  String get previous => '이전';

  @override
  String get hint => '힌트';

  @override
  String get restartPuzzle => '퍼즐 다시 시작';

  @override
  String get next => '다음';

  @override
  String get savedCorrupt => '저장된 게임이 손상되어 일부만 불러왔습니다';

  @override
  String get menuBughouse => '버그하우스';

  @override
  String get bugMode => '모드';

  @override
  String get bugHotSeat => '핫시트 (4인)';

  @override
  String get bugVsAi => '컴퓨터와 대전';

  @override
  String get bugYourSeat => '내 자리';

  @override
  String get bugBoardA => '보드 A';

  @override
  String get bugBoardB => '보드 B';

  @override
  String get bugWhite => '백';

  @override
  String get bugBlack => '흑';

  @override
  String bugTeamWins(String team) {
    return '$team 팀 승리';
  }

  @override
  String get bugStart => '경기 시작';

  @override
  String get bugLan => 'LAN';

  @override
  String get bugHostMatch => '매치 호스트';

  @override
  String get bugJoinMatch => '매치 참가';

  @override
  String get bugWaitingHost => '호스트가 시작하기를 기다리는 중…';

  @override
  String get bugPlayersJoined => '참가한 플레이어';

  @override
  String get bugAssignSeats => '네 자리 배정';

  @override
  String get bugSeatHost => '호스트 (나)';

  @override
  String get variant => '변형';

  @override
  String get vStandard => '스탠다드';

  @override
  String get vThreeCheck => '3체크';

  @override
  String get vKingOfTheHill => '킹 오브 더 힐';

  @override
  String get vChess960 => '체스960';

  @override
  String get vAtomic => '아토믹';

  @override
  String get vCrazyhouse => '크레이지하우스';

  @override
  String get vFogOfWar => '안개 전쟁 체스';

  @override
  String get menuFourPlayer => '4인전';

  @override
  String get fourFormat => '형식';

  @override
  String get fourFFA => '개인전';

  @override
  String get fourTeams => '팀전 (2대2)';

  @override
  String get fourVsBots => '봇 대전';

  @override
  String get fourYourSeats => '내 자리';

  @override
  String get fourRed => '빨강';

  @override
  String get fourBlue => '파랑';

  @override
  String get fourYellow => '노랑';

  @override
  String get fourGreen => '초록';

  @override
  String fourTeamWins(String team) {
    return '$team 승리';
  }

  @override
  String fourWins(String player) {
    return '$player 승리';
  }

  @override
  String fogPassDevice(String color) {
    return '기기를 $color에게 건네주세요';
  }

  @override
  String get fogTapReveal => '화면을 탭하여 당신의 차례를 확인하세요';

  @override
  String get checksLabel => '체크 수';

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
