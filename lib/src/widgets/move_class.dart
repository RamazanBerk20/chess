import 'package:flutter/material.dart';

import 'package:chess/l10n/app_localizations.dart';

/// Visual style (symbol + colour) for a move classification. Pass
/// `colorblind: true` for a red-green-colourblind-safe palette (good = blue
/// shades, bad = orange/vermillion). Labels are localised via [classLabel].
({String sym, Color color, String label}) classStyle(String c,
    {bool colorblind = false}) {
  final col = colorblind ? _cbColor(c) : _color(c);
  return (sym: _sym(c), color: col, label: _enLabel(c));
}

/// Localised one-line coach explanation for a move; [bestSan] is the engine's
/// preferred move in SAN (used by the templates that name a better move).
String coachText(AppLocalizations t, String cls, String bestSan) =>
    switch (cls) {
      'brilliant' => t.coachBrilliant,
      'great' => t.coachGreat,
      'best' => t.coachBest,
      'book' => t.coachBook,
      'good' => t.coachGood,
      'inaccuracy' => t.coachInaccuracy(bestSan),
      'miss' => t.coachMiss(bestSan),
      'mistake' => t.coachMistake(bestSan),
      'blunder' => t.coachBlunder(bestSan),
      _ => '',
    };

/// Localised display label for a classification.
String classLabel(AppLocalizations t, String c) => switch (c) {
      'brilliant' => t.clsBrilliant,
      'great' => t.clsGreat,
      'best' => t.clsBest,
      'good' => t.clsGood,
      'book' => t.clsBook,
      'inaccuracy' => t.clsInaccuracy,
      'miss' => t.clsMiss,
      'mistake' => t.clsMistake,
      'blunder' => t.clsBlunder,
      _ => '',
    };

String _sym(String c) => switch (c) {
      'brilliant' => '!!',
      'great' => '!',
      'best' => '★',
      'good' => '✓',
      'book' => '📖',
      'inaccuracy' => '?!',
      'miss' => '✗',
      'mistake' => '?',
      'blunder' => '??',
      _ => '',
    };

Color _color(String c) => switch (c) {
      'brilliant' => const Color(0xFF1BAAA0),
      'great' => const Color(0xFF2E9D8F),
      'best' => const Color(0xFF6FA84B),
      'good' => const Color(0xFF7C9D55),
      'book' => const Color(0xFF9E8B6B),
      'inaccuracy' => const Color(0xFFE0A53F),
      'miss' => const Color(0xFFB23A48),
      'mistake' => const Color(0xFFE07B39),
      'blunder' => const Color(0xFFCA3431),
      _ => Colors.grey,
    };

/// Colourblind-safe: good moves in blue/teal, bad moves in orange/vermillion
/// (distinguishable under red-green colour vision deficiency).
Color _cbColor(String c) => switch (c) {
      'brilliant' => const Color(0xFF12A2B8),
      'great' => const Color(0xFF1E88E5),
      'best' => const Color(0xFF2B7DE0),
      'good' => const Color(0xFF5B9BD5),
      'book' => const Color(0xFF9E8B6B),
      'inaccuracy' => const Color(0xFFE0A53F),
      'miss' => const Color(0xFFD55E00),
      'mistake' => const Color(0xFFE07B39),
      'blunder' => const Color(0xFFB34700),
      _ => Colors.grey,
    };

String _enLabel(String c) => switch (c) {
      'brilliant' => 'Brilliant',
      'great' => 'Great',
      'best' => 'Best',
      'good' => 'Good',
      'book' => 'Book',
      'inaccuracy' => 'Inaccuracy',
      'miss' => 'Miss',
      'mistake' => 'Mistake',
      'blunder' => 'Blunder',
      _ => '',
    };

/// The classifications the Rust analysis emits, in display order (best → worst).
const List<String> analysisClassOrder = [
  'brilliant',
  'best',
  'good',
  'book',
  'inaccuracy',
  'miss',
  'mistake',
  'blunder',
];
