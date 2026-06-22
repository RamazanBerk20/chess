import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chess/l10n/app_localizations.dart';
import 'package:chess/src/features/menu/main_menu.dart';
import 'package:chess/src/rust/frb_generated.dart';
import 'package:chess/src/state/settings.dart';
import 'package:chess/src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  await preloadSettings(); // seed persisted settings before first frame
  runApp(const ProviderScope(child: ChessApp()));
}

class ChessApp extends ConsumerWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: s.materialThemeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: s.localeCode == null ? null : Locale(s.localeCode!),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Apply an explicit text-size override (1.0 = follow the OS).
      builder: (context, child) {
        if (s.textScale == 1.0 || child == null) return child ?? const SizedBox();
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(s.textScale)),
          child: child,
        );
      },
      home: const MainMenu(),
    );
  }
}
