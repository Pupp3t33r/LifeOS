import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/security/ui/app_lock_gate.dart';
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
      // Gates the authenticated app behind the biometric app-lock on native
      // (no-op on web and when disabled/unsupported). See AppLockGate.
      builder: (context, child) =>
          AppLockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
