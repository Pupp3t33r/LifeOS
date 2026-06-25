# ADR-0014: Authentication UX — session lifetimes, passkeys, and biometric app-lock

## Status

Accepted

Date: 2026-06-25

**Relates to:** [ADR-0004](./0004-zero-trust-jwt-validation.md) (zero-trust JWT validation) settles how services *validate* tokens; this ADR settles the *lifetimes* of those tokens and *how the user authenticates and stays signed in*. It also records the per-platform OIDC scope and the Wallet login UX. Auth is cross-cutting (Keycloak realm config + Wallet client + service validation); like ADR-0004 it lives in the Money ADR folder as the platform's auth-decision lineage.

## Context

The Wallet is a personal-finance app — money is sensitive, so the bar for "don't get robbed" is high — but it is also a daily-use app, so the bar for "don't pester me" is high too. These pull in opposite directions, and the naïve readings of each are both wrong:

- "Don't pester me" naïvely → very long sessions everywhere. Unsafe: a long-lived token in browser storage, or on a handed-over unlocked phone, is a standing liability.
- "It's money, be strict" naïvely → short sessions + re-authenticate constantly. Pesters the user into either turning security off or abandoning the app.

Authentication itself is off-the-shelf: Keycloak (realm `lifeos`, single issuer fronted by the Gateway) and the Flutter `oidc` client. We own only configuration and client UX, not the auth engine. So every choice below is a **configuration or client-feature** decision, not something to build from scratch.

Three forces clarify the design:

1. **Session length and "who is at the device right now" are different questions.** Keycloak sessions answer *"is this an enrolled user?"* (long-lived). They do **not** answer *"is the person physically holding this device me?"* — that is a local, per-open concern. Conflating them produces either an insecure long token with no local guard, or a nagging short session.
2. **Platforms differ in how safely they can hold a long-lived token.** Native/desktop have an OS keychain and an app sandbox; web has neither (browser storage, XSS surface, no real app-lock). The same "stay logged in for months" posture is appropriate on a phone and inappropriate in a browser.
3. **Keycloak already models the split for us.** Online (SSO) sessions and offline sessions have independent idle/max timers. A client that requests the `offline_access` scope gets an *offline* session (long timers); one that does not gets an *online* SSO session (short timers). So a single realm configuration yields per-platform behavior, selected by whether the platform requests `offline_access` — no per-client lifetime overrides needed.

State at the time of this ADR: nothing token/session-related is configured in `lifeos-realm.json`, so everything runs on Keycloak 26 defaults (access token 5 min; SSO idle 30 min / max 10 h; offline idle 30 days / max disabled; refresh-token rotation off; brute-force off). The Wallet requests `offline_access` on every platform. Login is password-only.

## Decision

### 1. Two layers, kept separate

- **Session (server):** Keycloak issues a short access token plus a refresh/offline token; the app refreshes silently. Governs *"are you an enrolled user."* Long where safe, short where not.
- **App-lock (local, native only):** a local biometric gate (Flutter `local_auth`) protects the device-stored session. Governs *"is the person here right now you."* Sub-second, offline, no server round-trip. This is the layer that makes a long-lived native token safe to hold — it is the enabler of the convenience, not a tax on it.

### 2. Per-platform posture

| | **Native — Android / Windows / Linux desktop** | **Web** |
|---|---|---|
| `offline_access` scope | **Requested** → offline session | **Not requested** → online SSO session |
| Token at rest | OS keychain + app sandbox | Browser storage (kept short on purpose) |
| Access token lifespan | 5 min (silent refresh, invisible) | 5 min |
| Idle timeout | **60 days** (offline session idle) | **30 min** (SSO session idle) |
| Max lifespan | **180 days** (offline session max, enabled) | **24 h** (SSO session max) |
| Per-open guard | **Biometric app-lock** (local) | Passkey re-login when the session lapses |
| Re-auth cadence | ~once every 6 months | ~daily / after any multi-hour gap |
| Types a password? | Effectively never | Effectively never (passkey) |

The native numbers come from the **offline** session timers; the web numbers from the **online SSO** session timers. Because web omits `offline_access` and native includes it, one realm configuration produces both columns.

### 3. Login methods — passkey preferred, password always available

- **Passkeys (WebAuthn / FIDO2, platform authenticator)** are the preferred login method: the device's biometric/PIN authenticates to Keycloak with no typed secret. Configured as a realm authentication-flow alternative.
- **Password remains a first-class, always-reachable fallback.** It is never removed. It is required for the bootstrap case (first login on a new device, before any passkey or local lock exists) and for recovery (biometric unavailable, sensor failure, borrowed machine). The hosted login offers "sign in with passkey" and a reachable "use password instead."

### 4. Biometric app-lock UX (native)

- Required on **cold start**; on resume, re-lock only if the app was backgrounded longer than a short grace (≈5 min) so quick app-switching does not re-prompt.
- **Configurable**, default **on** for this money app.
- Fallbacks, in order: device passcode (via `local_auth`) → full Keycloak re-auth (where password is available). The lock screen never traps the user.
- The lock screen always carries **"Use password"** and **"Log out / Sign in as a different account."** Logout clears the local tokens and ends the session at Keycloak (RP-initiated logout, already wired via `postLogoutRedirectUri`), returning to a clean login for a different user.

### 5. Refresh-token rotation and hardening

- **Refresh-token rotation on** (`revokeRefreshToken: true`, `refreshTokenMaxReuse: 0`) for the public `wallet-app` client — one-time-use refresh tokens with replay detection.
- **Brute-force protection on** in non-dev environments.
- Access-token lifespan stays 5 min; clock-skew and signature validation are unchanged (ADR-0004).

### 6. Realm/client settings this implies

Realm `lifeos` (applies to online sessions = web; offline sessions = native; selected by scope):

| Setting | Value |
|---|---|
| `accessTokenLifespan` | 300 (5 min) |
| `ssoSessionIdleTimeout` | 1800 (30 min) |
| `ssoSessionMaxLifespan` | 86400 (24 h) |
| `offlineSessionIdleTimeout` | 5184000 (60 days) |
| `offlineSessionMaxLifespanEnabled` | true |
| `offlineSessionMaxLifespan` | 15552000 (180 days) |
| `revokeRefreshToken` | true |
| `bruteForceProtected` | true (non-dev) |
| WebAuthn passwordless policy + flow | enabled, password retained as alternative |

`wallet-app` client: request `offline_access` on native/desktop only, omit on web (`AuthConfig.scopes` gated on `kIsWeb`).

## Consequences

Positive:

- The "don't pester me" goal is met where it is safe to meet it: on the daily-driver native apps the user faces only a sub-second biometric on open and a full re-auth roughly twice a year.
- Web gets a posture appropriate to a money app on an untrusted surface (short-lived token, ~daily passkey re-login) **without** ever asking the user to type a password.
- The biometric app-lock makes the long native token safe rather than risky, and is the lowest-friction security primitive available.
- Password-always-available removes lockout/bootstrap/borrowed-device failure modes that a passkey-only design would create.
- Refresh-token rotation limits the blast radius of a leaked refresh token.
- One realm configuration yields both platform postures via the `offline_access` scope choice — no per-client lifetime overrides to maintain.

Negative:

- Web users re-authenticate about daily (or after a multi-hour gap). Accepted: it is a single passkey tap, and a browser is the wrong place to hold a long-lived money credential.
- A 60-day-idle / 180-day-max offline token is a long-lived credential on the device. Mitigated by the keychain + app sandbox, the biometric app-lock, refresh-token rotation, and the absolute 180-day cap. (The cap could be disabled for a true "never log me out," trading hygiene for convenience — deliberately kept.)
- The biometric app-lock and passkey support are **Wallet client features not yet built** (`local_auth`, the lock-screen UX, the passkey enrollment/login flow). Until they ship, native falls back to password login and has no local gate.
- Applying these settings to the **running dev** Keycloak does not happen by editing `realm.json` alone: the persistent Postgres volume makes realm import skip an existing realm, so dev changes must go via the admin API or a realm re-import/volume reset (same operational gap noted for schema in `PLAN.md §8`).

Neutral:

- The access-token lifespan (5 min) and ADR-0004 validation are unchanged.
- The `money-api` dev client (password grant, known secret) is unaffected — it uses the online SSO timers and remains dev-only; productionizing it is out of scope here (see `PLAN.md §8`).
- WebAuthn passkeys require a secure context (HTTPS) and a stable RP ID (domain) in production; `localhost` is a secure context for dev.

## Alternatives Considered

1. **One long session on every platform, including web.** Simplest, maximal convenience. Rejected: a months-long token in browser storage is an XSS-exfiltration liability for a money app — an anti-pattern, not a feature.
2. **Short sessions everywhere + biometric re-auth at the server each time.** Treats biometry as the whole answer. Rejected: without a local app-lock layer it just trades a password prompt for a biometric prompt every 30 minutes — still pestering — and gains none of the long-session convenience.
3. **Password-only (no passkeys).** Rejected: typing friction and weaker phishing resistance; passkeys are the modern, lower-friction default. Password is retained as fallback, not as the primary.
4. **Passkey-only (drop password).** Rejected: creates lockout and bootstrap problems (first device, lost authenticator, borrowed machine) for a solo user who cannot fall back to an admin. Password must remain reachable.
5. **No local app-lock; rely on the OS device lock screen.** Rejected: a handed-over or already-unlocked device would expose finances directly. The app-lock is cheap defense-in-depth and is what makes the long native session acceptable.
6. **Per-client lifetime overrides to get the platform split.** Rejected as unnecessary: the online/offline session timers already produce the split for free, selected by the `offline_access` scope. Per-client overrides remain available later if a platform needs to diverge.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
