import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// A board colour scheme.
class BoardThemeOption {
  final String name;
  final Color light;
  final Color dark;
  const BoardThemeOption(this.name, this.light, this.dark);
}

const boardThemes = <BoardThemeOption>[
  BoardThemeOption('Green', Color(0xFFEEEED2), Color(0xFF769656)),
  BoardThemeOption('Brown', Color(0xFFF0D9B5), Color(0xFFB58863)),
  BoardThemeOption('Blue', Color(0xFFDEE3E6), Color(0xFF8CA2AD)),
  BoardThemeOption('Gray', Color(0xFFDCDCDC), Color(0xFF909090)),
];

class Settings {
  final int boardTheme; // index into boardThemes
  final bool soundOn;
  final bool showHints;
  final int animationMs;
  final bool haptics;
  final String defaultTc; // time-control preset label
  final String defaultDifficulty; // difficulty preset name
  final String themeMode; // 'system' | 'light' | 'dark'
  final bool highContrast; // accessibility: stark board colours
  final bool colorblind; // accessibility: colourblind-safe move-quality palette
  final double textScale; // 1.0 = follow OS; >1 enlarges text
  final String? localeCode; // null = follow system; else 'en','tr',…

  const Settings({
    this.boardTheme = 0,
    this.soundOn = true,
    this.showHints = true,
    this.animationMs = 150,
    this.haptics = true,
    this.defaultTc = 'Infinite',
    this.defaultDifficulty = 'Medium',
    this.themeMode = 'dark',
    this.highContrast = false,
    this.colorblind = false,
    this.textScale = 1.0,
    this.localeCode,
  });

  BoardThemeOption get theme {
    if (highContrast) {
      return const BoardThemeOption(
          'High contrast', Color(0xFFFFFFFF), Color(0xFF1A1A1A));
    }
    return boardThemes[boardTheme.clamp(0, boardThemes.length - 1)];
  }

  ThemeMode get materialThemeMode => switch (themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Settings copyWith({
    int? boardTheme,
    bool? soundOn,
    bool? showHints,
    int? animationMs,
    bool? haptics,
    String? defaultTc,
    String? defaultDifficulty,
    String? themeMode,
    bool? highContrast,
    bool? colorblind,
    double? textScale,
    String? localeCode,
    bool clearLocale = false,
  }) =>
      Settings(
        boardTheme: boardTheme ?? this.boardTheme,
        soundOn: soundOn ?? this.soundOn,
        showHints: showHints ?? this.showHints,
        animationMs: animationMs ?? this.animationMs,
        haptics: haptics ?? this.haptics,
        defaultTc: defaultTc ?? this.defaultTc,
        defaultDifficulty: defaultDifficulty ?? this.defaultDifficulty,
        themeMode: themeMode ?? this.themeMode,
        highContrast: highContrast ?? this.highContrast,
        colorblind: colorblind ?? this.colorblind,
        textScale: textScale ?? this.textScale,
        localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
      );

  Map<String, dynamic> toJson() => {
        'boardTheme': boardTheme,
        'soundOn': soundOn,
        'showHints': showHints,
        'animationMs': animationMs,
        'haptics': haptics,
        'defaultTc': defaultTc,
        'defaultDifficulty': defaultDifficulty,
        'themeMode': themeMode,
        'highContrast': highContrast,
        'colorblind': colorblind,
        'textScale': textScale,
        'localeCode': localeCode,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        boardTheme: j['boardTheme'] as int? ?? 0,
        soundOn: j['soundOn'] as bool? ?? true,
        showHints: j['showHints'] as bool? ?? true,
        animationMs: j['animationMs'] as int? ?? 150,
        haptics: j['haptics'] as bool? ?? true,
        defaultTc: j['defaultTc'] as String? ?? 'Infinite',
        defaultDifficulty: j['defaultDifficulty'] as String? ?? 'Medium',
        themeMode: j['themeMode'] as String? ?? 'dark',
        highContrast: j['highContrast'] as bool? ?? false,
        colorblind: j['colorblind'] as bool? ?? false,
        textScale: (j['textScale'] as num?)?.toDouble() ?? 1.0,
        localeCode: j['localeCode'] as String?,
      );
}

Future<File> _file() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/settings.json');
}

Future<Settings> _load() async {
  try {
    final f = await _file();
    if (!await f.exists()) return const Settings();
    return Settings.fromJson(json.decode(await f.readAsString()) as Map<String, dynamic>);
  } catch (_) {
    return const Settings();
  }
}

Future<void> _save(Settings s) async {
  try {
    final f = await _file();
    await f.writeAsString(json.encode(s.toJson()));
  } catch (_) {}
}

/// Settings loaded from disk before `runApp`, so the first frame (and any
/// one-shot reads in setup screens) sees the persisted values, not defaults.
Settings _bootSettings = const Settings();

/// Call once in `main()` before `runApp`.
Future<void> preloadSettings() async {
  _bootSettings = await _load();
}

final settingsProvider =
    NotifierProvider<SettingsController, Settings>(SettingsController.new);

class SettingsController extends Notifier<Settings> {
  @override
  Settings build() => _bootSettings;

  void _update(Settings s) {
    state = s;
    _save(s);
  }

  void setBoardTheme(int i) => _update(state.copyWith(boardTheme: i));
  void setSound(bool v) => _update(state.copyWith(soundOn: v));
  void setHints(bool v) => _update(state.copyWith(showHints: v));
  void setAnimationMs(int v) => _update(state.copyWith(animationMs: v));
  void setHaptics(bool v) => _update(state.copyWith(haptics: v));
  void setDefaultTc(String v) => _update(state.copyWith(defaultTc: v));
  void setDefaultDifficulty(String v) =>
      _update(state.copyWith(defaultDifficulty: v));
  void setThemeMode(String v) => _update(state.copyWith(themeMode: v));
  void setHighContrast(bool v) => _update(state.copyWith(highContrast: v));
  void setColorblind(bool v) => _update(state.copyWith(colorblind: v));
  void setTextScale(double v) => _update(state.copyWith(textScale: v));
  void setLocale(String? code) => _update(
      code == null ? state.copyWith(clearLocale: true) : state.copyWith(localeCode: code));
}
