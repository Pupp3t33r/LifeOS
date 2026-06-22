import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/calm_tokens.dart';
import 'auth_controller.dart';

/// The single in-app auth surface. It does **not** collect credentials — login,
/// registration, and password reset are all hosted by Keycloak (see
/// app/auth/README.md). This screen just launches the right hosted flow and
/// shows progress; the router guard sends the user here when unauthenticated.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: authState.when(
              loading: () => const CircularProgressIndicator(),
              error: (_, _) => _ErrorView(
                onRetry: () => ref.invalidate(authStateProvider),
              ),
              data: (_) => const _SignInContent(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInContent extends ConsumerStatefulWidget {
  const _SignInContent();

  @override
  ConsumerState<_SignInContent> createState() => _SignInContentState();
}

class _SignInContentState extends ConsumerState<_SignInContent> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      // Most common cause is the user cancelling the hosted flow — keep it calm.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in was not completed: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = ref.read(authActionsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Wallet',
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(
            fontFamily: CalmTokens.fontDisplay,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Plan your month, not just your balance.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 40),
        FilledButton(
          onPressed: _busy ? null : () => _run(actions.signIn),
          child: _busy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('Sign in'),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: _busy ? null : () => _run(actions.register),
          child: const Text('Create account'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : () => _run(actions.signIn),
          child: const Text('Forgot password?'),
        ),
        const SizedBox(height: 24),
        Text(
          'Secured by LifeOS single sign-on.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off, size: 40, color: theme.colorScheme.onSurface),
        const SizedBox(height: 16),
        Text(
          "Couldn't reach the sign-in service.",
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Check your connection and try again.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
