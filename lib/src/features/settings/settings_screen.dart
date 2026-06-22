import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/state/difficulty.dart';
import 'package:chess/src/state/settings.dart';
import 'package:chess/src/state/time_control.dart';
import 'package:chess/src/state/update_service.dart';
import 'package:chess/src/widgets/update_dialog.dart';

/// Locale code → native display name (null = follow the system).
const _localeNames = <String?, String>{
  null: '',
  'en': 'English',
  'tr': 'Türkçe',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'ru': 'Русский',
  'ar': 'العربية',
  'ja': '日本語',
  'zh': '中文',
  'ko': '한국어',
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListView(
        children: [
          _Header(t.appearance),
          ListTile(
            title: Text(t.theme),
            trailing: DropdownButton<String>(
              value: s.themeMode,
              onChanged: (v) => v != null ? c.setThemeMode(v) : null,
              items: [
                DropdownMenuItem(value: 'system', child: Text(t.themeSystem)),
                DropdownMenuItem(value: 'light', child: Text(t.themeLight)),
                DropdownMenuItem(value: 'dark', child: Text(t.themeDark)),
              ],
            ),
          ),
          ListTile(
            title: Text(t.boardThemeLabel),
            trailing: DropdownButton<int>(
              value: s.boardTheme,
              onChanged: s.highContrast
                  ? null
                  : (v) => v != null ? c.setBoardTheme(v) : null,
              items: [
                for (int i = 0; i < boardThemes.length; i++)
                  DropdownMenuItem(value: i, child: Text(boardThemes[i].name)),
              ],
            ),
          ),
          _Header(t.language),
          ListTile(
            title: Text(t.language),
            trailing: DropdownButton<String?>(
              value: s.localeCode,
              onChanged: c.setLocale,
              items: [
                for (final entry in _localeNames.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.key == null
                        ? t.languageSystem
                        : entry.value),
                  ),
              ],
            ),
          ),
          _Header(t.accessibility),
          SwitchListTile(
            title: Text(t.highContrast),
            value: s.highContrast,
            onChanged: c.setHighContrast,
          ),
          SwitchListTile(
            title: Text(t.colorblindSafe),
            value: s.colorblind,
            onChanged: c.setColorblind,
          ),
          ListTile(
            title: Text(t.textSize),
            subtitle: Slider(
              value: s.textScale,
              min: 0.8,
              max: 1.6,
              divisions: 8,
              label: '${(s.textScale * 100).round()}%',
              onChanged: c.setTextScale,
            ),
          ),
          _Header(t.gameplay),
          SwitchListTile(
            title: Text(t.moveHints),
            value: s.showHints,
            onChanged: c.setHints,
          ),
          SwitchListTile(
            title: Text(t.sound),
            value: s.soundOn,
            onChanged: c.setSound,
          ),
          SwitchListTile(
            title: Text(t.haptics),
            value: s.haptics,
            onChanged: c.setHaptics,
          ),
          ListTile(
            title: Text(t.animationSpeed),
            subtitle: Slider(
              value: s.animationMs.toDouble(),
              min: 0,
              max: 400,
              divisions: 8,
              label: s.animationMs == 0 ? 'off' : '${s.animationMs} ms',
              onChanged: (v) => c.setAnimationMs(v.round()),
            ),
          ),
          _Header(t.defaultTimeControl),
          ListTile(
            title: Text(t.defaultTimeControl),
            trailing: DropdownButton<String>(
              value: s.defaultTc,
              onChanged: (v) => v != null ? c.setDefaultTc(v) : null,
              items: [
                for (final p in TimeControlOption.presets)
                  DropdownMenuItem(value: p.label, child: Text(p.label)),
              ],
            ),
          ),
          ListTile(
            title: Text(t.defaultDifficulty),
            trailing: DropdownButton<String>(
              value: s.defaultDifficulty,
              onChanged: (v) => v != null ? c.setDefaultDifficulty(v) : null,
              items: [
                for (final d in Difficulty.presets)
                  DropdownMenuItem(value: d.name, child: Text(d.name)),
              ],
            ),
          ),
          _Header(t.support),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: Text(t.donate),
            subtitle: Text(t.donateSubtitle),
            onTap: () => openUrl(sponsorUrl),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: Text(t.checkForUpdates),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(SnackBar(
                content: Text(t.checkingForUpdates),
                duration: const Duration(seconds: 1),
              ));
              final info = await checkForUpdate();
              if (!context.mounted) return;
              await showUpdateResult(context, info);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(t.about),
            subtitle: FutureBuilder<String>(
              future: currentVersion(),
              builder: (_, snap) => Text(snap.hasData ? 'v${snap.data}' : ''),
            ),
            onTap: () => openUrl(repoUrl),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
