import 'package:flutter/material.dart';

import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/state/update_service.dart';

/// Show the result of an update check. `info == null` → "up to date" (suppressed
/// when [silent], e.g. an automatic startup check). Otherwise offer to download.
Future<void> showUpdateResult(
  BuildContext context,
  UpdateInfo? info, {
  bool silent = false,
}) async {
  final t = AppLocalizations.of(context);
  if (info == null) {
    if (silent) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.checkForUpdates),
        content: Text(t.upToDate),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t.ok)),
        ],
      ),
    );
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(t.updateAvailable),
      content: Text('${t.newVersionAvailable} ${info.version}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(t.later)),
        FilledButton(
          onPressed: () {
            Navigator.pop(c);
            openUrl(info.apkUrl ?? info.htmlUrl);
          },
          child: Text(t.download),
        ),
      ],
    ),
  );
}
