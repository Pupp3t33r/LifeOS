import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/auth/auth_controller.dart';
import '../application/security_providers.dart';
import 'lock_screen.dart';

/// Wraps the whole app (via `MaterialApp.builder`) and shows [LockScreen] when the
/// biometric app-lock is engaged (ADR-0014). It is a **pure passthrough** unless
/// the lock is genuinely active — native, supported, enabled, and signed in — so
/// on web (and on unsupported/disabled/signed-out states) it renders the child
/// unchanged and never touches `local_auth`.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  /// Quick app-switches shouldn't re-prompt; a real absence should.
  static const Duration _grace = Duration(minutes: 5);

  bool _locked = true; // locked on cold start — only consulted once the lock is active
  bool _prompting = false;
  bool _autoPrompted = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      if (since != null && DateTime.now().difference(since) > _grace) {
        _lock();
      }
    }
  }

  bool get _active {
    if (kIsWeb) return false;
    final supported = ref.watch(biometricSupportedProvider).maybeWhen(data: (v) => v, orElse: () => false);
    final enabled = ref.watch(appLockEnabledProvider).maybeWhen(data: (v) => v, orElse: () => false);
    final authed = ref.watch(authStateProvider).maybeWhen(data: (a) => a.isAuthenticated, orElse: () => false);
    return supported && enabled && authed;
  }

  void _lock() {
    if (!mounted) return;
    setState(() {
      _locked = true;
      _autoPrompted = false;
    });
  }

  Future<void> _unlockWithBiometrics() async {
    if (_prompting) return;
    setState(() => _prompting = true);
    final ok = await ref.read(biometricServiceProvider).authenticate('Unlock Wallet');
    if (!mounted) return;
    setState(() {
      _prompting = false;
      if (ok) _locked = false;
    });
  }

  Future<void> _usePassword() async {
    try {
      await ref.read(authActionsProvider).signIn();
      if (mounted) setState(() => _locked = false);
    } catch (_) {
      // Re-auth cancelled/failed: stay locked.
    }
  }

  Future<void> _switchAccount() async {
    try {
      await ref.read(authActionsProvider).signOut();
      // Session cleared → [_active] becomes false → router sends the user to sign-in.
    } catch (_) {
      // ignore; the user can retry
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-lock whenever a fresh authenticated session appears (first login, or a
    // log-out → log-in as a different account), so the new session is gated too.
    ref.listen(authStateProvider, (previous, next) {
      final wasAuthed = previous?.maybeWhen(data: (a) => a.isAuthenticated, orElse: () => false) ?? false;
      final nowAuthed = next.maybeWhen(data: (a) => a.isAuthenticated, orElse: () => false);
      if (nowAuthed && !wasAuthed) _lock();
    });

    if (!_active || !_locked) return widget.child;

    // Auto-present the OS prompt once per lock (banking-app feel), without spamming.
    if (!_autoPrompted && !_prompting) {
      _autoPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _unlockWithBiometrics();
      });
    }

    return LockScreen(
      busy: _prompting,
      onUnlock: _unlockWithBiometrics,
      onUsePassword: _usePassword,
      onSwitchAccount: _switchAccount,
    );
  }
}
