import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import 'auth_config.dart';

/// Builds the Keycloak-backed [OidcUserManager] for the Wallet app.
///
/// Authorization Code + PKCE against the `wallet-app` public client. Tokens
/// persist via [OidcDefaultStore], which keeps sensitive values
/// (access/refresh/id tokens) in `flutter_secure_storage` and the rest in
/// shared preferences. The manager is created lazily and is **not** initialized
/// here — callers must `await manager.init()` first (see `auth_controller.dart`).
OidcUserManager buildWalletAuthManager() {
  return OidcUserManager.lazy(
    discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
      Uri.parse(AuthConfig.issuer),
    ),
    // Public client → no secret.
    clientCredentials: const OidcClientAuthentication.none(
      clientId: AuthConfig.clientId,
    ),
    store: OidcDefaultStore(),
    settings: OidcUserManagerSettings(
      scope: AuthConfig.scopes,
      redirectUri: AuthConfig.redirectUri,
      postLogoutRedirectUri: AuthConfig.postLogoutRedirectUri,
    ),
  );
}
