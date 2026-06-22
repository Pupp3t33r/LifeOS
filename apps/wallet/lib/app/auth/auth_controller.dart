import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oidc/oidc.dart';
import 'auth_manager.dart';
import 'auth_state.dart';

/// Owns the [OidcUserManager] for the app's lifetime.
final authManagerProvider = Provider<OidcUserManager>((ref) {
  final manager = buildWalletAuthManager();
  ref.onDispose(manager.dispose);
  return manager;
});

/// Initializes the OIDC manager once (restoring any persisted session), then
/// streams auth state. `null` user → unauthenticated. The manager handles
/// silent token refresh internally and emits through this stream, so the rest
/// of the app never touches tokens directly — it watches this provider.
///
/// Surfaces as `AsyncLoading` during init and `AsyncError` if Keycloak is
/// unreachable; the router guard treats both as "not yet signed in".
final authStateProvider = StreamProvider<AuthState>((ref) async* {
  final manager = ref.watch(authManagerProvider);
  await manager.init();
  yield AuthState.fromUser(manager.currentUser);
  yield* manager.userChanges().map(AuthState.fromUser);
});

/// Imperative auth actions for the sign-in screen. Each kicks off a hosted
/// Keycloak flow; the resulting state change is observed via [authStateProvider]
/// (these intentionally return `void` work, not the user).
final authActionsProvider = Provider<AuthActions>((ref) {
  return AuthActions(ref.watch(authManagerProvider));
});

class AuthActions {
  AuthActions(this._manager);

  final OidcUserManager _manager;

  /// Opens Keycloak's hosted login page. That page also carries the
  /// "Forgot password?" reset link (enabled realm-wide), so password recovery
  /// flows through here too — there is no separate in-app reset screen by
  /// design (passwords never touch the app; see app/auth/README.md).
  Future<void> signIn() async {
    await _manager.loginAuthorizationCodeFlow();
  }

  /// Opens Keycloak's hosted **registration** page via OIDC `prompt=create`.
  /// Accounts created here are realm-wide: every LifeOS app honors them via SSO.
  Future<void> register() async {
    await _manager.loginAuthorizationCodeFlow(promptOverride: ['create']);
  }

  /// Ends the session at Keycloak and clears locally stored tokens.
  Future<void> signOut() async {
    await _manager.logout();
  }
}
