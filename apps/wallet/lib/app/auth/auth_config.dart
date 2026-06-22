import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Static OIDC configuration for the Wallet app's Keycloak `wallet-app` client
/// (public client, Authorization Code + PKCE, realm `lifeos`).
///
/// Redirect URIs are per-platform and MUST match what's registered on the
/// `wallet-app` client in `aspire/LifeOS.AppHost/keycloak/lifeos-realm.json`:
///  - native (Android/iOS/macOS): custom scheme `dev.lifeos.wallet:/…`
///  - desktop (Windows/Linux): loopback `http://localhost:<random>` (port 0)
///  - web: an actual page at `<origin>/auth.html`
///
/// Platform detection uses `defaultTargetPlatform` (not `dart:io`) so this file
/// also compiles for web.
class AuthConfig {
  AuthConfig._();

  /// Keycloak realm issuer. Dev default matches the Aspire-hosted Keycloak
  /// (fixed host port 8080, see AppHost.cs). Override per environment with
  /// `--dart-define=OIDC_ISSUER=https://auth.example.com/realms/lifeos`.
  static const String issuer = String.fromEnvironment(
    'OIDC_ISSUER',
    defaultValue: 'http://localhost:8080/realms/lifeos',
  );

  /// Public client id registered in the `lifeos` realm.
  static const String clientId = 'wallet-app';

  /// `openid` is mandatory; `offline_access` yields a refresh token so the
  /// session survives restarts via the token store.
  static const List<String> scopes = <String>[
    'openid',
    'profile',
    'email',
    'offline_access',
  ];

  /// Reverse-DNS scheme for native redirects. Mirrors the Android
  /// `appAuthRedirectScheme` manifest placeholder.
  static const String _nativeScheme = 'dev.lifeos.wallet';

  static bool get _isApple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Where Keycloak sends the user back after authentication.
  static Uri get redirectUri {
    if (kIsWeb) return Uri.base.resolve('auth.html');
    if (_isAndroid || _isApple) {
      return Uri.parse('$_nativeScheme:/oauth2redirect');
    }
    // Windows / Linux: OS-assigned loopback port (safer than a fixed one).
    return Uri.parse('http://localhost:0');
  }

  /// Where Keycloak sends the user back after logout.
  static Uri get postLogoutRedirectUri {
    if (kIsWeb) return Uri.base.resolve('auth.html');
    if (_isAndroid || _isApple) {
      return Uri.parse('$_nativeScheme:/endsessionredirect');
    }
    return Uri.parse('http://localhost:0');
  }
}
