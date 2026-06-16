# LifeOS Design System

System-wide design tokens for LifeOS. This folder is a **registry of shared themes** —
the single source of truth for the visual language used across every surface (the Keycloak
login screens today, the Wallet Flutter app next, and any future web/service UI).

Each surface picks one theme to wear. **"Calm"** is the first theme: warm bone surfaces, a
sage primary with a clay secondary, Bricolage Grotesque display + Spline Sans body, soft radii
and gentle shadows.

```
design/
  README.md                    ← this file
  themes/
    calm/                      ← theme #1
      tokens.json              ← Calm's source of truth (edit here first)
      bindings/
        tokens.css             ← web / Keycloak binding (live)
        tokens.dart            ← Flutter binding (added when Wallet starts)
    <next-theme>/              ← future themes drop in here, same shape
      tokens.json
      bindings/...
```

## Why a neutral source per theme

The surfaces that consume a theme don't share a language:

| Surface | Stack | Binding |
|---|---|---|
| Keycloak login | FreeMarker + CSS | `themes/<t>/bindings/tokens.css` |
| Wallet app | Flutter / Dart | `themes/<t>/bindings/tokens.dart` *(future)* |

A stylesheet can't be shared with Flutter, so each theme's **canonical definition lives in its
`tokens.json`** (platform-neutral), and each platform gets a thin *binding* that mirrors it.

## Token naming: per-theme vocabulary

Each theme **names its own tokens** — Calm uses `sage` / `clay` / `bone`; another theme might
use `rust` / `gold` / `ash`. There is intentionally no shared semantic contract: a consumer's
stylesheet is written against one theme's vocabulary.

Practical consequence: the Keycloak login CSS references `--lifeos-sage` etc., so it is bound to
Calm. Reskinning that surface means either mounting a Calm-shaped binding or updating the CSS to
the new theme's names. (If we later want truly swap-in-place themes for a surface, that's when a
shared semantic contract would be introduced — deferred until a second theme actually needs it.)

The `--lifeos-` prefix is the org namespace; the token name after it belongs to the theme.

## Light / dark modes

**Modes live *inside* a theme, not as separate themes.** Dark mode is the same brand (same token
vocabulary) with different values, so light and dark share token *names* — a consumer flips mode
with zero code change. A genuinely different look (e.g. a Terminal aesthetic) gets its own theme
folder; light/dark/high-contrast of one brand do not.

In `tokens.json`, a token value is **either**:

- a **string** — mode-independent (fonts, radii, the brand gradient), or
- an **object `{ "light": …, "dark": … }`** — mode-aware (most colors, the card shadow).

The CSS binding emits light values in `:root`, then a dark override applied two ways:

```css
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) { /* dark vars */ }   /* OS default */
}
[data-theme="dark"] { /* dark vars */ }                  /* explicit choice — wins */
```

Resolution: an explicit `data-theme` on `<html>` wins; otherwise the OS `prefers-color-scheme`
decides. Setting `data-theme="light"` forces light even when the OS is dark.

### Toggle + persistence (Keycloak login)

The login theme renders a corner toggle that sets `data-theme` on `<html>` and stores the choice
in **`localStorage` (key `lifeos-theme`) on the Keycloak origin**. An inline `<head>` script
applies it before first paint (no flash). Notes:

- Persistence is **scoped to the Keycloak origin** — it survives across logins there, but does
  **not** automatically carry to the Wallet app (a different origin). Each app stores its own
  choice and defaults to the OS preference. There is no pre-auth way to read a server-side user
  attribute, so client storage is the correct mechanism for the sign-in screen.
- The Flutter binding will expose `ThemeData.light()` + `ThemeData.dark()` and let the app drive
  mode from `ThemeMode.system` + a stored override, mirroring this behavior.

## The sync rule (within a theme)

1. **Change `themes/<t>/tokens.json` first.** It is authoritative for that theme.
2. **Update each binding to match.** Today Calm has one binding (`tokens.css`).
3. Keep the value *and* the comment header in each binding pointing back to its `tokens.json`.

There is no generator yet (Calm has a single binding, so the overhead isn't worth it). When a
second binding appears (Wallet's `tokens.dart`), add a small build step that emits the bindings
from `tokens.json`, and those files become generated artifacts.

## Adding a theme

1. Copy `themes/calm/` to `themes/<name>/`.
2. Rewrite `tokens.json` with the new vocabulary + values; update `meta.name`.
3. Regenerate/author its bindings.
4. Point the consuming surface at it (for Keycloak, change the bind-mount source in
   `aspire/LifeOS.AppHost/AppHost.cs`; see below).

## How Keycloak consumes Calm (live)

The AppHost bind-mounts Calm's CSS binding into the `lifeos` login theme's resources at container
start, so the login page renders the shared palette without copying it:

```
design/themes/calm/bindings/tokens.css
  → /opt/keycloak/themes/lifeos/login/resources/css/tokens.css
```

The theme's `styles.css` does `@import "tokens.css";` then references the `--lifeos-*` properties.
Editing the tokens and restarting Keycloak (dev mode hot-reloads themes) updates the login look —
no theme edit required. Mounting a different theme's binding at that path reskins the page.

## Calm tokens at a glance

| Token | Value | Use |
|---|---|---|
| `color.bone` | `#F4F1EA` | App background |
| `color.surface` | `#FBFAF6` | Cards / sheets |
| `color.ink` | `#2C2A26` | Primary text |
| `color.muted` | `#7C766B` | Secondary text |
| `color.line` | `#E6E1D6` | Borders / dividers |
| `color.sage` / `color.sageDeep` | `#5E7E6B` / `#4E6B5A` | Primary accent + gradient |
| `color.clay` | `#C07A52` | Secondary accent / errors |
| `font.display` | Bricolage Grotesque | Headings, brand |
| `font.body` | Spline Sans | Body, controls |
| `radius.sm/md/lg` | 14 / 18 / 28 px | Inputs+buttons / badges / cards |
| `gradient.brand` | sage → sageDeep | Primary buttons, brand mark |
