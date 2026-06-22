import 'package:flutter/material.dart';

import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/features/newgame/new_game_hub_screen.dart';
import 'package:chess/src/features/puzzles/puzzle_screen.dart';
import 'package:chess/src/features/saved/resume_screen.dart';
import 'package:chess/src/features/settings/settings_screen.dart';
import 'package:chess/src/state/update_service.dart';
import 'package:chess/src/widgets/update_dialog.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  @override
  void initState() {
    super.initState();
    // One quiet check on launch: prompt only when a newer release exists.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final info = await checkForUpdate();
      if (!mounted || info == null) return;
      await showUpdateResult(context, info, silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    void go(Widget screen) => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
    return Scaffold(
      appBar: AppBar(title: Text(t.appTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Text(
                  '♞', // ♞ knight — the classic chess emblem (ChessGlyphs font)
                  style: TextStyle(
                    fontFamily: 'ChessGlyphs',
                    fontSize: 96,
                    height: 1.0,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(t.appTitle,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 24),
                _MenuButton(
                    icon: Icons.play_circle_outline,
                    label: t.newGame,
                    onTap: () => go(const NewGameHubScreen())),
                _MenuButton(
                    icon: Icons.extension,
                    label: t.menuPuzzles,
                    onTap: () => go(const PuzzleScreen())),
                _MenuButton(
                    icon: Icons.history,
                    label: t.menuResume,
                    onTap: () => go(const ResumeScreen())),
                _MenuButton(
                    icon: Icons.settings,
                    label: t.menuSettings,
                    onTap: () => go(const SettingsScreen())),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => openUrl(sponsorUrl),
                  icon: const Icon(Icons.favorite, color: Color(0xFFE25555)),
                  label: Text(t.donate),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        enabled: onTap != null,
        onTap: onTap,
      ),
    );
  }
}
