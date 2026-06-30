import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import 'outbox_drainer.dart';

/// Lifecycle glue that keeps the outbox draining without the UI having to ask.
///
/// Once watched (the app shell keeps it alive), it drains whenever an
/// authenticated session appears — i.e. on app launch with a restored session
/// and again on each fresh sign-in. That covers the "replay on reconnect" case
/// for the common reconnect path (relaunch); true connectivity-driven auto-drain
/// (`connectivity_plus`) is a later add. The other trigger — right after an
/// [enqueue] — is the feature's call: `ref.read(outboxDrainerProvider).drain()`.
///
/// Draining while signed out is pointless (every call would 401), so it is gated
/// on [AuthState.isAuthenticated]. Overlapping triggers are harmless: the drainer
/// coalesces them onto one in-flight pass.
final outboxSyncProvider = Provider<void>((ref) {
  final drainer = ref.watch(outboxDrainerProvider);
  ref.listen<AsyncValue<AuthState>>(
    authStateProvider,
    (previous, next) {
      final authed = next.value?.isAuthenticated ?? false;
      final wasAuthed = previous?.value?.isAuthenticated ?? false;
      // Drain on the transition into an authenticated session (and on the first
      // resolved value if it's already authenticated), not on every token churn.
      if (authed && !wasAuthed) {
        drainer.drain();
      }
    },
    fireImmediately: true,
  );
});
