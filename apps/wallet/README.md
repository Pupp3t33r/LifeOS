# Wallet

Personal-finance **planner** client for the LifeOS platform — the primary consumer of the
[Money service](../../services/money/AGENTS.md). Built with Flutter (Dart).

- **Conventions & architecture:** [AGENTS.md](./AGENTS.md)
- **Roadmap & scope:** [PLAN.md](./PLAN.md)
- **Stack:** Riverpod · drift (SQLite) · Dio + OpenAPI (dart-dio) · go_router · flutter_appauth (Keycloak OIDC) · flutter_secure_storage
- **Targets:** Android, Web, Windows. (Linux is in scope but builds only on a Linux/CI host, not Windows.)

---

## Prerequisites

- **Flutter SDK** (3.44.2 stable) installed at `C:\dev\Flutter`, with `C:\dev\Flutter\bin` on your `PATH`.
- Verify the full toolchain is healthy:
  ```bash
  flutter doctor
  ```
  All of Flutter / Android toolchain / Chrome / Visual Studio should be green. If `flutter` isn't
  found, open a new terminal (PATH is set at the user level) or call it by full path
  `C:\dev\Flutter\bin\flutter`.

---

## First-time setup

From this directory (`apps/wallet`):

```bash
flutter pub get          # restore dependencies (also run after pulling pubspec changes)
```

---

## Run (with hot reload)

```bash
flutter devices          # list connected devices/targets and their ids

flutter run -d chrome    # Web (fastest feedback loop)
flutter run -d windows   # Windows desktop
flutter run -d <id>      # Android emulator or device (id from `flutter devices`)
```

While `flutter run` is attached:

| Key | Action |
|-----|--------|
| `r` | Hot reload (apply Dart changes, keep state) |
| `R` | Hot restart (rebuild app, reset state) |
| `p` | Toggle debug paint (widget bounds) |
| `o` | Toggle platform (Android/iOS rendering) |
| `q` | Quit |

Pick a build mode with `--debug` (default), `--profile` (perf testing), or `--release`.

---

## Debug

- Hot reload/restart are available live in `flutter run` (see keys above).
- **DevTools** (inspector, network, performance, logging) — the URL is printed when you `flutter run`,
  or launch standalone:
  ```bash
  dart devtools
  ```
- IDE debugging: open the folder in VS Code (Dart/Flutter extensions) or Android Studio and press F5 —
  breakpoints, the widget inspector, and the debug console all work against `flutter run`.
- More logs:
  ```bash
  flutter run -v          # verbose tooling output
  flutter logs            # stream device logs
  ```

---

## Test, analyze, format

```bash
flutter test                       # run unit/widget tests
flutter test test/widget_test.dart # run a single test file
flutter analyze                    # static analysis (lints from analysis_options.yaml)
dart format .                      # format all Dart sources
```

---

## Code generation (drift)

drift tables/DAOs and any other generated sources use `build_runner`:

```bash
dart run build_runner build --delete-conflicting-outputs   # one-shot
dart run build_runner watch --delete-conflicting-outputs   # regenerate on change
```

> The OpenAPI Dio client (`lib/features/money/data/api/`) is generated separately from Money's
> `/openapi/v1.json` once that spec is live — see [AGENTS.md](./AGENTS.md). Not wired up yet.

---

## Build (release artifacts)

```bash
flutter build web        # -> build/web
flutter build windows    # -> build/windows/x64/runner/Release/wallet.exe
flutter build apk        # -> build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle  # -> Play Store .aab
```

---

## Maintenance

```bash
flutter pub add <package>            # add a dependency (updates pubspec.yaml)
flutter pub outdated                 # show dependencies with newer versions
flutter pub upgrade                  # upgrade within version constraints
flutter clean                        # delete build/ and caches (then `flutter pub get`)
```

---

## Project layout

```
lib/
  main.dart                  app entry (ProviderScope + WalletApp)
  app/                       shell: auth, navigation, sync, theme
  features/
    money/                   Phase 1 feature module
      data/{drift,api,outbox}
      domain/                Dart models (e.g. Money value object)
      ui/<screen>/           one folder per screen (vertical slice)
  shared/                    cross-feature widgets/utils
```

See [AGENTS.md](./AGENTS.md) for the rules that govern this structure.
