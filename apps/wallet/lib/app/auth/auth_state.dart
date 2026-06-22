import 'package:oidc/oidc.dart';

/// Whether a user session currently exists.
enum AuthStatus { unauthenticated, authenticated }

/// Immutable snapshot of the app's authentication state, derived from the
/// OIDC manager's current [OidcUser] (`null` → unauthenticated).
class AuthState {
  const AuthState({required this.status, this.user});

  final AuthStatus status;
  final OidcUser? user;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Stable Keycloak subject (`sub`) — the value Money scopes data by
  /// (`owner_id`, see Money ADR-0004). Null when unauthenticated.
  String? get userId => user?.uid;

  /// Bearer token for API calls. The OIDC manager refreshes it transparently.
  String? get accessToken => user?.token.accessToken;

  /// Best available human label for the signed-in user.
  String? get displayName {
    final claims = user?.aggregatedClaims;
    if (claims == null) return null;
    return (claims['name'] ??
        claims['preferred_username'] ??
        claims['email']) as String?;
  }

  factory AuthState.fromUser(OidcUser? user) => AuthState(
        status:
            user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated,
        user: user,
      );
}
