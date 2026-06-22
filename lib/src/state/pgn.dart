import 'package:chess/src/rust/api/game.dart';

/// Build a PGN string from a game's SAN moves + result. Pure Dart — the SAN
/// move list and outcome already come from the Rust [GameView].
String buildPgn({
  required List<String> sanMoves,
  required GameOutcome status,
  String white = 'White',
  String black = 'Black',
  String event = 'Casual game',
  String? date, // "YYYY.MM.DD"
  String? startFen, // non-null for games started from a custom position
}) {
  final result = switch (status) {
    GameOutcome.whiteWins || GameOutcome.whiteWinsOnTime => '1-0',
    GameOutcome.blackWins || GameOutcome.blackWinsOnTime => '0-1',
    GameOutcome.stalemate ||
    GameOutcome.drawFiftyMove ||
    GameOutcome.drawThreefold ||
    GameOutcome.drawInsufficientMaterial =>
      '1/2-1/2',
    GameOutcome.ongoing => '*',
  };

  final b = StringBuffer()
    ..writeln('[Event "$event"]')
    ..writeln('[Site "Chess app"]')
    ..writeln('[Date "${date ?? '????.??.??'}"]')
    ..writeln('[White "${_esc(white)}"]')
    ..writeln('[Black "${_esc(black)}"]')
    ..writeln('[Result "$result"]');
  if (startFen != null &&
      startFen != 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1') {
    b
      ..writeln('[SetUp "1"]')
      ..writeln('[FEN "$startFen"]');
  }
  b.writeln();

  // Movetext: "1. e4 e5 2. Nf3 …", wrapped to ~80 columns.
  final tokens = <String>[];
  for (var i = 0; i < sanMoves.length; i++) {
    if (i.isEven) tokens.add('${i ~/ 2 + 1}.');
    tokens.add(sanMoves[i]);
  }
  tokens.add(result);

  var line = '';
  for (final tok in tokens) {
    if (line.isNotEmpty && line.length + tok.length + 1 > 80) {
      b.writeln(line);
      line = '';
    }
    line = line.isEmpty ? tok : '$line $tok';
  }
  if (line.isNotEmpty) b.writeln(line);
  return b.toString();
}

String _esc(String s) => s.replaceAll('"', "'");
