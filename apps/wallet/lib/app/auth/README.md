# app/auth

Shell-level authentication. **Keycloak OIDC** (Authorization Code + PKCE) via the
[`oidc`](https://pub.dev/packages/oidc) package — chosen over `flutter_appauth`
because it covers all our targets (Android, iOS, macOS, **Web, Windows, Linux**);
`flutter_appauth` is mobile/macOS only. Tokens persist via `OidcDefaultStore`
(`flutter_secure_storage` for sensitive values).

- **Realm/issuer:** `…/realms/lifeos` (dev: `http://localhost:8080/realms/lifeos`,
  override with `--dart-define=OIDC_ISSUER=…`).
- **Client:** public client `wallet-app` (PKCE S256, no secret), registered in
  `aspire/LifeOS.AppHost/keycloak/lifeos-realm.json`. Its access tokens carry
  `aud: money-api` via an audience mapper so they pass Money's zero-trust JWT
  validation (services/money ADR-0004).
- **Credentials are realm-wide.** Registration and password reset are enabled on
  the `lifeos` realm, so accounts created here work across every LifeOS app via SSO.

## Hosted pages, not in-app forms

Login, **registration**, and **password reset** are rendered by Keycloak's hosted
pages (themed "Calm" — see `keycloak/themes/lifeos`), **not** built as Flutter
screens. The app never sees a password. The only in-app auth surface is
`sign_in_screen.dart`, a landing that launches the right hosted flow:

| Button | Flow |
|---|---|
| **Sign in** | `loginAuthorizationCodeFlow()` — Keycloak's login page (also hosts the "Forgot password?" reset link) |
| **Create account** | `loginAuthorizationCodeFlow(promptOverride: ['create'])` — Keycloak's registration page |
| **Forgot password?** | same as Sign in; the reset link lives on Keycloak's login page |

## Files

- `auth_config.dart` — issuer, client id, scopes, per-platform redirect URIs.
- `auth_manager.dart` — builds the `OidcUserManager`.
- `auth_state.dart` — `AuthState` snapshot (status, user id, access token, display name).
- `auth_controller.dart` — Riverpod providers: `authManagerProvider`,
  `authStateProvider` (live session stream), `authActionsProvider` (sign in /
  register / sign out).
- `sign_in_screen.dart` — the landing surface.

The router guard (`app/navigation/app_router.dart`) sends unauthenticated users to
`/sign-in` and authenticated users away from it. Redirect URIs must match the
`wallet-app` client: native `dev.lifeos.wallet:/…` (Android scheme set in
`android/app/build.gradle.kts`), desktop loopback `http://localhost:0`, web
`<origin>/auth.html` (`web/auth.html`; run dev web with `--web-port 22433`).
