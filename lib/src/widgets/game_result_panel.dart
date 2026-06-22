import 'package:flutter/material.dart';

import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/theme/spacing.dart';

/// Consistent end-of-game actions: Analyze · Play Again · Main Menu · Export.
/// Each action is a callback so the same panel serves the standard, bughouse,
/// and four-player screens; pass null to hide an action a screen doesn't offer.
class GameResultPanel extends StatelessWidget {
  final VoidCallback? onAnalyze;
  final VoidCallback onPlayAgain;
  final VoidCallback onMainMenu;
  final VoidCallback? onExportPgn;
  const GameResultPanel({
    super.key,
    required this.onPlayAgain,
    required this.onMainMenu,
    this.onAnalyze,
    this.onExportPgn,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          if (onAnalyze != null)
            FilledButton.icon(
              onPressed: onAnalyze,
              icon: const Icon(Icons.analytics_outlined),
              label: Text(t.analyzeGame),
            ),
          OutlinedButton.icon(
            onPressed: onPlayAgain,
            icon: const Icon(Icons.replay),
            label: Text(t.playAgain),
          ),
          OutlinedButton.icon(
            onPressed: onMainMenu,
            icon: const Icon(Icons.home_outlined),
            label: Text(t.mainMenu),
          ),
          if (onExportPgn != null)
            OutlinedButton.icon(
              onPressed: onExportPgn,
              icon: const Icon(Icons.ios_share),
              label: Text(t.exportPgn),
            ),
        ],
      ),
    );
  }
}
