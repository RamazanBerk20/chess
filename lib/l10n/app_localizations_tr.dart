// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Satranç';

  @override
  String get menuSinglePlayer => 'Tek Oyuncu';

  @override
  String get menuTwoPlayers => 'İki Oyuncu';

  @override
  String get menuLan => 'LAN üzerinden oyna';

  @override
  String get menuPuzzles => 'Bulmacalar';

  @override
  String get menuResume => 'Oyuna Devam Et';

  @override
  String get menuSettings => 'Ayarlar';

  @override
  String get menuPlayFromPosition => 'Pozisyondan Oyna';

  @override
  String get ok => 'Tamam';

  @override
  String get cancel => 'İptal';

  @override
  String get save => 'Kaydet';

  @override
  String get delete => 'Sil';

  @override
  String get rename => 'Yeniden adlandır';

  @override
  String get close => 'Kapat';

  @override
  String get retry => 'Yeniden dene';

  @override
  String get copy => 'Kopyala';

  @override
  String get share => 'Paylaş';

  @override
  String get start => 'Başlat';

  @override
  String get accept => 'Kabul et';

  @override
  String get decline => 'Reddet';

  @override
  String get send => 'Gönder';

  @override
  String get whiteToMove => 'Beyaz oynayacak';

  @override
  String get blackToMove => 'Siyah oynayacak';

  @override
  String get whiteToMoveCheck => 'Beyaz oynayacak — şah!';

  @override
  String get blackToMoveCheck => 'Siyah oynayacak — şah!';

  @override
  String get checkmateWhiteWins => 'Şah mat — Beyaz kazandı';

  @override
  String get checkmateBlackWins => 'Şah mat — Siyah kazandı';

  @override
  String get whiteWinsOnTime => 'Süreden Beyaz kazandı';

  @override
  String get blackWinsOnTime => 'Süreden Siyah kazandı';

  @override
  String get drawStalemate => 'Beraberlik — pat';

  @override
  String get drawFiftyMove => 'Beraberlik — elli hamle kuralı';

  @override
  String get drawThreefold => 'Beraberlik — üç kez tekrar';

  @override
  String get drawInsufficient => 'Beraberlik — yetersiz materyal';

  @override
  String get resign => 'Terk et';

  @override
  String get offerDraw => 'Beraberlik teklif et';

  @override
  String get drawOfferTitle => 'Beraberlik teklifi';

  @override
  String get drawOfferBody => 'Rakibiniz beraberlik teklif ediyor.';

  @override
  String get takeBack => 'Hamleyi geri al';

  @override
  String get newGame => 'Yeni oyun';

  @override
  String get mainMenu => 'Ana menü';

  @override
  String get flipBoard => 'Tahtayı çevir';

  @override
  String get autoFlipOn => 'Otomatik çevirme: açık';

  @override
  String get autoFlipOff => 'Otomatik çevirme: kapalı';

  @override
  String get saveGame => 'Oyunu kaydet';

  @override
  String get aiMove => 'Yapay zekâ hamlesi (oynayacak taraf)';

  @override
  String get playAgain => 'Tekrar oyna';

  @override
  String get analyzeGame => 'Oyunu analiz et';

  @override
  String get gameSaved => 'Oyun kaydedildi';

  @override
  String get boardDesync => 'Tahta senkronizasyonu bozuldu — oyun iptal edildi';

  @override
  String get youResigned => 'Terk ettiniz — kaybettiniz';

  @override
  String get opponentResigned => 'Rakip terk etti — kazandınız';

  @override
  String get drawAgreed => 'Beraberlik kabul edildi';

  @override
  String get opponentDisconnected => 'Rakibin bağlantısı kesildi';

  @override
  String get name => 'İsim';

  @override
  String get gameName => 'Oyun adı';

  @override
  String get myGame => 'Oyunum';

  @override
  String get analysis => 'Analiz';

  @override
  String get white => 'Beyaz';

  @override
  String get black => 'Siyah';

  @override
  String get accuracy => 'isabet';

  @override
  String analyzingProgress(Object done, Object total) {
    return 'Analiz ediliyor $done/$total…';
  }

  @override
  String get preparingAnalysis => 'Analiz hazırlanıyor…';

  @override
  String get clsBrilliant => 'Muhteşem';

  @override
  String get clsGreat => 'Harika';

  @override
  String get clsBest => 'En iyi';

  @override
  String get clsGood => 'İyi';

  @override
  String get clsBook => 'Kitap';

  @override
  String get clsInaccuracy => 'Hatalı';

  @override
  String get clsMiss => 'Kaçırma';

  @override
  String get clsMistake => 'Hata';

  @override
  String get clsBlunder => 'Vahim hata';

  @override
  String get coachBrilliant => 'Muhteşem — kazandıran bir feda.';

  @override
  String get coachGreat => 'Harika — durumu kurtaran tek hamle.';

  @override
  String get coachBest => 'En iyi hamle.';

  @override
  String get coachBook => 'Bilinen bir açılış hamlesi.';

  @override
  String get coachGood => 'İyi bir hamle.';

  @override
  String coachInaccuracy(Object best) {
    return 'Hatalı — $best biraz daha iyiydi.';
  }

  @override
  String coachMiss(Object best) {
    return 'Kazandıran bir fırsat kaçtı — $best çok daha güçlüydü.';
  }

  @override
  String coachMistake(Object best) {
    return 'Hata — $best daha güçlüydü.';
  }

  @override
  String coachBlunder(Object best) {
    return 'Vahim hata — $best çok daha iyiydi.';
  }

  @override
  String get settings => 'Ayarlar';

  @override
  String get appearance => 'Görünüm';

  @override
  String get boardThemeLabel => 'Tahta teması';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeDark => 'Koyu';

  @override
  String get language => 'Dil';

  @override
  String get languageSystem => 'Sistem varsayılanı';

  @override
  String get accessibility => 'Erişilebilirlik';

  @override
  String get highContrast => 'Yüksek kontrastlı tahta';

  @override
  String get colorblindSafe => 'Renk körlüğüne uygun hamle renkleri';

  @override
  String get textSize => 'Yazı boyutu';

  @override
  String get gameplay => 'Oynanış';

  @override
  String get sound => 'Ses';

  @override
  String get moveHints => 'Hamle ipuçları';

  @override
  String get haptics => 'Titreşim';

  @override
  String get animationSpeed => 'Animasyon hızı';

  @override
  String get defaultTimeControl => 'Varsayılan süre kontrolü';

  @override
  String get defaultDifficulty => 'Varsayılan zorluk';

  @override
  String get hostGame => 'Oyun kur';

  @override
  String get joinGame => 'Oyuna katıl';

  @override
  String get yourName => 'Adınız';

  @override
  String get yourColour => 'Renginiz';

  @override
  String get colourWhite => 'Beyaz';

  @override
  String get colourBlack => 'Siyah';

  @override
  String get colourRandom => 'Rastgele';

  @override
  String get hostAGame => 'Bir oyun kur';

  @override
  String get joinOnNetwork => 'Bu ağdaki bir oyuna katıl';

  @override
  String get searchingHosts => 'Sunucular aranıyor…';

  @override
  String get waitingOpponent => 'Bir rakibin bağlanması bekleniyor…';

  @override
  String get lanGame => 'LAN oyunu';

  @override
  String get chat => 'Sohbet';

  @override
  String get typeMessage => 'Bir mesaj yazın…';

  @override
  String get savedGames => 'Kaydedilen oyunlar';

  @override
  String get noSavedGames => 'Henüz kaydedilmiş oyun yok';

  @override
  String get resume => 'Devam et';

  @override
  String get renameGameTitle => 'Oyunu yeniden adlandır';

  @override
  String get playFromPosition => 'Pozisyondan Oyna';

  @override
  String get pasteFen => 'Bir FEN dizesi yapıştırın';

  @override
  String get fenHint =>
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  String get invalidFen => 'Geçersiz FEN — pozisyon dizesini kontrol edin';

  @override
  String get useStartPosition => 'Başlangıç pozisyonunu kullan';

  @override
  String get loadPosition => 'Pozisyonu yükle';

  @override
  String get sideToPlay => 'Oynayacak taraf FEN tarafından belirlenir';

  @override
  String get exportPgn => 'PGN\'yi dışa aktar';

  @override
  String get copyPgn => 'PGN\'yi kopyala';

  @override
  String get copyMoves => 'Hamleleri kopyala';

  @override
  String get copiedToClipboard => 'Panoya kopyalandı';

  @override
  String get game => 'Oyun';

  @override
  String get singlePlayerTitle => 'Tek Oyuncu - Yapay Zekâya Karşı';

  @override
  String get twoPlayerTitle => 'İki oyuncu - aynı cihaz';

  @override
  String get lanTitle => 'İki oyuncu - LAN';

  @override
  String get playAs => 'Şu renkle oyna';

  @override
  String get difficulty => 'Zorluk';

  @override
  String get timeControl => 'Süre kontrolü';

  @override
  String get startGame => 'Oyunu başlat';

  @override
  String get custom => 'Özel';

  @override
  String get tcInfinite => 'Sınırsız';

  @override
  String get diffBeginner => 'Acemi';

  @override
  String get diffEasy => 'Kolay';

  @override
  String get diffMedium => 'Orta';

  @override
  String get diffHard => 'Zor';

  @override
  String get diffExpert => 'Uzman';

  @override
  String get baseMinutes => 'Temel dakika';

  @override
  String get incrementSeconds => 'Artış saniyesi';

  @override
  String get baseTimeError => 'Temel süre en az 1 dakika olmalı';

  @override
  String get searchDepth => 'Arama derinliği';

  @override
  String get timePerMove => 'Hamle/süre (ms)';

  @override
  String get topNRandom => 'İlk-N rastgele';

  @override
  String get blunderChance => 'Hata yapma olasılığı';

  @override
  String get evalNoise => 'Değerlendirme gürültüsü (cp)';

  @override
  String puzzlesSolved(Object solved, Object total) {
    return '$solved/$total çözüldü';
  }

  @override
  String get alreadySolved => 'zaten çözüldü';

  @override
  String get puzzleWrong => 'Doğru hamle değil - tekrar dene';

  @override
  String get puzzleSolvedMsg =>
      'Çözüldü! ✓  Sonraki bulmaca için ▶ düğmesine dokun';

  @override
  String puzzleFooter(
    Object index,
    Object total,
    Object rating,
    Object streak,
    Object best,
  ) {
    return 'Bulmaca $index/$total  ·  puan $rating  ·  seri $streak (en iyi $best)';
  }

  @override
  String get loadPuzzlesFailed => 'Bulmacalar yüklenemedi';

  @override
  String get previous => 'Önceki';

  @override
  String get hint => 'İpucu';

  @override
  String get restartPuzzle => 'Bulmacayı yeniden başlat';

  @override
  String get next => 'Sonraki';

  @override
  String get savedCorrupt => 'Kaydedilen oyun bozuktu; kısmen yüklendi';

  @override
  String get menuBughouse => 'Bughouse';

  @override
  String get bugMode => 'Mod';

  @override
  String get bugHotSeat => 'Tek cihazda (4 oyuncu)';

  @override
  String get bugVsAi => 'Bilgisayara karşı';

  @override
  String get bugYourSeat => 'Yeriniz';

  @override
  String get bugBoardA => 'Tahta A';

  @override
  String get bugBoardB => 'Tahta B';

  @override
  String get bugWhite => 'Beyaz';

  @override
  String get bugBlack => 'Siyah';

  @override
  String bugTeamWins(String team) {
    return '$team takımı kazanır';
  }

  @override
  String get bugStart => 'Maçı başlat';

  @override
  String get bugLan => 'LAN';

  @override
  String get bugHostMatch => 'Maç oluştur';

  @override
  String get bugJoinMatch => 'Maça katıl';

  @override
  String get bugWaitingHost => 'Ev sahibinin başlatması bekleniyor…';

  @override
  String get bugPlayersJoined => 'Katılan oyuncular';

  @override
  String get bugAssignSeats => 'Dört koltuğu ata';

  @override
  String get bugSeatHost => 'Ev sahibi (sen)';

  @override
  String get variant => 'Varyant';

  @override
  String get vStandard => 'Standart';

  @override
  String get vThreeCheck => 'Üç Şah';

  @override
  String get vKingOfTheHill => 'Tepenin Kralı';

  @override
  String get vChess960 => 'Chess960';

  @override
  String get vAtomic => 'Atomik';

  @override
  String get vCrazyhouse => 'Crazyhouse';

  @override
  String get vFogOfWar => 'Sisli Satranç';

  @override
  String get menuFourPlayer => '4 Oyunculu';

  @override
  String get fourFormat => 'Format';

  @override
  String get fourFFA => 'Herkes Tek Başına';

  @override
  String get fourTeams => 'Takımlar (2\'ye 2)';

  @override
  String get fourVsBots => 'Botlara Karşı';

  @override
  String get fourYourSeats => 'Koltuklarınız';

  @override
  String get fourRed => 'Kırmızı';

  @override
  String get fourBlue => 'Mavi';

  @override
  String get fourYellow => 'Sarı';

  @override
  String get fourGreen => 'Yeşil';

  @override
  String fourTeamWins(String team) {
    return '$team kazandı';
  }

  @override
  String fourWins(String player) {
    return '$player kazandı';
  }

  @override
  String fogPassDevice(String color) {
    return 'Cihazı $color oyuncusuna ver';
  }

  @override
  String get fogTapReveal => 'Hamleni görmek için dokun';

  @override
  String get checksLabel => 'Şahlar';

  @override
  String get support => 'Destek';

  @override
  String get donate => 'Bağış yap';

  @override
  String get donateSubtitle => 'GitHub Sponsors ile geliştirmeyi destekle';

  @override
  String get checkForUpdates => 'Güncellemeleri denetle';

  @override
  String get checkingForUpdates => 'Güncellemeler denetleniyor…';

  @override
  String get upToDate => 'En son sürümü kullanıyorsunuz.';

  @override
  String get updateAvailable => 'Güncelleme mevcut';

  @override
  String get newVersionAvailable => 'Yeni bir sürüm mevcut:';

  @override
  String get download => 'İndir';

  @override
  String get later => 'Sonra';

  @override
  String get about => 'Hakkında';
}
