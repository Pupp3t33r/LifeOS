# Local development — running with hot reload against the Aspire stack

Two ways to run the app locally, depending on whether you need the backend.

## A. Standalone UI preview (no backend, no auth)

For pure UI work — layout, theming, widget behaviour — use the preview entrypoint. It
renders a screen directly on mock data, skipping auth, onboarding, and the nav shell:

```bash
flutter run -t lib/main_home_preview.dart -d chrome
```

This is the fastest loop and needs nothing else running. It's a throwaway harness
(`lib/main_home_preview.dart` + `home_mock.dart`, marked *delete-when-wired*); it renders
the **real** screen widgets, just with sample data injected.

## B. Full app against the local Aspire stack

For real auth + data, run the whole app pointed at the running stack (`aspire run`). Use the
helper — it sets the right flags per target:

```powershell
cd apps/wallet
./run-dev.ps1            # web on http://localhost:5555 (default)
./run-dev.ps1 windows
./run-dev.ps1 android    # add -Device <id> if several are connected
```

The Gateway-served static build (`http://localhost:5022`) keeps working alongside whichever
live target you launch.

---

## Why a dev workaround is needed (the cross-origin exception)

In production the Gateway serves the SPA **same-origin** and reverse-proxies `/realms/*`
(Keycloak) and `/api/money/*` (Money) — so the browser only ever talks to one origin and
there's **no CORS**. The app leans on this: on web it derives all its backend URLs from its
own origin (see `lib/app/auth/auth_config.dart` and `lib/features/money/data/money_api.dart`):

```dart
issuer    = Uri.base.resolve('realms/lifeos')   // http://<origin>/realms/lifeos
moneyBase = '${Uri.base.origin}/api/money'      // http://<origin>/api/money
```

`flutter run` serves the app on its **own** origin (e.g. `http://localhost:5555`), which
proxies nothing — so those derived paths don't exist. The workaround, per target:

| Target | What's needed | Why |
|---|---|---|
| **web** | `--dart-define=OIDC_ISSUER=...` + `--dart-define=MONEY_API_BASE=...` (point back at the Gateway), a Gateway **dev CORS** policy, and the dev origin registered on the Keycloak `wallet-app` client | The dev origin can't use the same-origin proxy, so auth + API are aimed at `localhost:5022` and the now-cross-origin Money calls need CORS. |
| **windows** | nothing | Native HTTP (no browser origin → no CORS); the loopback redirect is already registered and the app's native defaults already target `http://localhost:5022`. |
| **android** | `adb reverse tcp:5022 tcp:5022` + debug cleartext config | `localhost` on the device is the *device*; `adb reverse` maps it to the host Gateway, which keeps the token issuer consistent with `KC_HOSTNAME`. Android blocks cleartext HTTP by default. |

`run-dev.ps1` applies all of the above automatically.

### One-time setup (web only)

The Keycloak realm imports into its data volume **once**, so the added redirect origin
(`http://localhost:5555` on `wallet-app`) only takes effect after a re-import, and the Gateway
must be rebuilt to pick up the CORS policy:

```bash
docker volume rm keycloak-data    # ⚠️ wipes Keycloak dev state (sessions + passkey enrollments)
# then restart the Aspire stack (re-imports the realm; rebuilds the Gateway)
```

Windows and Android need none of this — they work against the current stack as soon as you
launch them.

### Where the pieces live

- `apps/wallet/run-dev.ps1` — the launcher (sets per-target flags).
- `aspire/LifeOS.AppHost/keycloak/lifeos-realm.json` — `wallet-app` redirect origins.
- `services/gateway/LifeOS.Gateway/{Program.cs, appsettings.Development.json}` — dev CORS policy + `Cors:DevOrigins`.
- `apps/wallet/android/app/src/debug/{AndroidManifest.xml, res/xml/network_security_config.xml}` — debug cleartext.

## Security scope

Every relaxation here is **development-only** and leaves production untouched:

- The Gateway CORS policy is registered and applied **only** under `IsDevelopment()`; outside
  Development no policy exists and the proxy stays same-origin/CORS-free.
- Android cleartext lives under `src/debug`, so **release builds keep cleartext off**.
- HTTPS in dev is intentionally not used — `localhost` (via `adb reverse` on Android) already
  counts as a secure context, so passkeys/secure-cookies still behave. See the HTTP-vs-HTTPS
  trade-off discussion before changing this.
