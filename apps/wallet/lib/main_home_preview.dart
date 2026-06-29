import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'shared/widgets/wordmark.dart';
import 'features/money/ui/month_overview/month_overview_screen.dart';

/// PREVIEW-ONLY entrypoint — renders the Home cockpit directly, bypassing auth,
/// onboarding, and the nav shell, so the screen can be screenshot-tested without
/// the backend or a Keycloak round-trip. NOT shipped; not referenced by the app.
///
///   flutter build web -t lib/main_home_preview.dart --output build/web_preview
///
/// Delete alongside `home_mock.dart` once Home is wired to the real projection.
void main() {
  runApp(const ProviderScope(child: _HomePreviewApp()));
}

class _HomePreviewApp extends StatefulWidget {
  const _HomePreviewApp();

  @override
  State<_HomePreviewApp> createState() => _HomePreviewAppState();
}

class _HomePreviewAppState extends State<_HomePreviewApp> {
  ThemeMode _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home preview',
      debugShowCheckedModeBanner: false,
      theme: walletLightTheme,
      darkTheme: walletDarkTheme,
      themeMode: _mode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(
          title: const Wordmark(),
          titleSpacing: 24,
          actions: [
            // Light/dark toggle so both modes can be screenshot from one build.
            IconButton(
              tooltip: 'Toggle theme',
              icon: Icon(_mode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              onPressed: () => setState(
                () => _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: const MonthOverviewScreen(),
      ),
    );
  }
}
