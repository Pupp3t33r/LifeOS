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

  /// Keycloak realm issuer.
  ///
  /// The Gateway reverse-proxies `/realms/*` to Keycloak and serves the web app
  /// same-origin, so on web we derive the issuer from the app's own origin — the
  /// same build works in dev, staging and prod with no per-environment config.
  /// Native/desktop builds have no web origin, so they fall back to the local
  /// Gateway. Either can be overridden with
  /// `--dart-define=OIDC_ISSUER=https://app.example.com/realms/lifeos`.
  static String get issuer {
    const override = String.fromEnvironment('OIDC_ISSUER');
    if (override.isNotEmpty) return override;
    if (kIsWeb) return Uri.base.resolve('realms/lifeos').toString();
    return 'http://localhost:5022/realms/lifeos';
  }

  /// Public client id registered in the `lifeos` realm.
  static const String clientId = 'wallet-app';

  /// `openid` is mandatory. `offline_access` yields an **offline** token that
  /// survives the SSO session ending — appropriate on native/desktop (secure OS
  /// keychain) but not in a browser, where a long-lived token sits in browser
  /// storage. So it is requested on native/desktop only and omitted on web; web
  /// gets a shorter online SSO session instead (Money ADR-0014).
  static List<String> get scopes => <String>[
        'openid',
        'profile',
        'email',
        if (!kIsWeb) 'offline_access',
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
