import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:chess/l10n/app_localizations.dart';

/// Bottom sheet showing a game's PGN with copy + share actions.
Future<void> showPgnExport(BuildContext context, String pgn) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.exportPgn, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  pgn,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: Text(t.copyPgn),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: pgn));
                      Navigator.pop(ctx);
                      messenger.showSnackBar(
                        SnackBar(content: Text(t.copiedToClipboard)),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.share),
                    label: Text(t.share),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Share.share(pgn);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
