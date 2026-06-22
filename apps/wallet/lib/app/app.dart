import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'navigation/app_router.dart';
import 'theme/app_theme.dart';

/// Root of the Wallet app — the shell. Wires routing and theme; feature
/// modules plug into the router here. Cross-feature communication goes
/// through the shell, never feature-to-feature (see apps/wallet/AGENTS.md).
class WalletApp extends ConsumerWidget {
  const WalletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Wallet',
      theme: walletLightTheme,
      darkTheme: walletDarkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
