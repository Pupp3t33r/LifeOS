import 'package:flutter/material.dart';
import '../../../app/theme/calm_tokens.dart';

/// The lock overlay shown over the authenticated app when the biometric app-lock
/// is engaged (ADR-0014). It never traps the user: alongside the biometric unlock
/// it always offers a password re-auth and a log-out / switch-account escape.
class LockScreen extends StatelessWidget {
  const LockScreen({
    super.key,
    required this.busy,
    required this.onUnlock,
    required this.onUsePassword,
    required this.onSwitchAccount,
  });

  final bool busy;
  final VoidCallback onUnlock;
  final VoidCallback onUsePassword;
  final VoidCallback onSwitchAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.lock_outline, size: 40, color: theme.colorScheme.primary),
                const SizedBox(height: 18),
                Text(
                  'Wallet is locked',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFamily: CalmTokens.fontDisplay,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlock to get back to your savings.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: busy ? null : onUnlock,
                  child: busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Unlock'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: busy ? null : onUsePassword,
                  child: const Text('Use password instead'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: busy ? null : onSwitchAccount,
                  child: Text(
                    'Log out / sign in as a different account',
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
