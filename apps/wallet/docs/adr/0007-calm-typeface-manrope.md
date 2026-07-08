# ADR-0007: Calm typeface — Manrope (single variable super-family, Latin + Cyrillic)

## Status

Accepted

Date: 2026-07-08

**Amends:** `design/themes/calm/tokens.json` and its bindings (`design/themes/calm/bindings/tokens.css`, `apps/wallet/lib/app/theme/calm_tokens.dart`) — the `font.display` and `font.body` tokens change family. Per the sync rule in [`design/README.md`](../../../../design/README.md), `tokens.json` is edited first, then each binding is mirrored.

**Relates to:** [Wallet ADR-0001](./0001-app-localization.md) (the localization decision that shipped English + Russian and exposed the Cyrillic gap this ADR closes), [Money ADR-0015](../../../../services/money/docs/adr/0015-fx-rate-sourcing-and-client-cache.md) (Belarus-local context — the primary user reads Russian), [Wallet ADR-0003](./0003-category-colour-system.md) (a co-consumer of the Calm token set that this amends), [`design/README.md`](../../../../design/README.md) (token sync rule).

## Context

The Calm theme ships two type roles from `design/themes/calm/tokens.json`:

```
"font": {
  "display": "\"Bricolage Grotesque\", sans-serif",
  "body":    "\"Spline Sans\", sans-serif"
}
```

Two facts make this a problem *now*, where it was merely latent before:

1. **Russian is shipped.** Wallet ADR-0001 localized the onboarding/settings surface to English + Russian, and the Keycloak login surface is Russian-capable (Keycloak ADR-0001). Russian text now renders in the app, not just in mockups.
2. **Spline Sans has no Cyrillic subset.** Bricolage Grotesque (display) does; Spline Sans (body) does not. So every Russian *body* string — which is almost every string in the app — falls back to the platform default (Roboto on Android, Segoe UI on Windows, the browser default on web) while Russian *headings* stay in Bricolage Grotesque. The result is a visible, in-paragraph glyph mismatch: mixed metrics, inconsistent stroke weight, "this app wasn't designed for my language."

Compounding the above, **no Calm font is bundled yet today** — see `apps/wallet/lib/app/theme/calm_tokens.dart` (lines 97–100): the family names are declared but the assets are not shipped, so *every* string currently renders in the platform default regardless of language. The Cyrillic gap is therefore not a regression waiting to happen; it is the default state the moment a Russian string appears. Resolving the font is a forcing function, not a nice-to-have.

Forces at play:

- **Cyrillic coverage is non-negotiable for the body role.** Body text is 95% of the words on screen; a fallback there is the thing the user actually sees. Display (headings) already has Cyrillic via Bricolage Grotesque, but body does not.
- **Mixed-font rendering is worse than a single consistent font.** Two typefaces with different x-heights, stroke contrast, and terminal treatments, sitting in the same line of text, reads as broken — especially bad in a personal-finance app where numbers and currency codes sit next to localized labels.
- **The Calm token set is shared across surfaces.** The Keycloak login wears the CSS binding; the Wallet app wears the Dart binding (vendored at `calm_tokens.dart`); category colours (ADR-0003) live in the same set. A font decision ripples through all of them, so it belongs in the design tokens, not in an app-private constant.
- **One family is simpler than two.** A single variable super-family covering both display and body roles (heavy weights for headings, light weights for text) halves the bundling/loading surface and guarantees metric consistency between roles and between scripts.
- **Warmth matters.** Calm's palette (sage / clay / bone) is warm; a cold neo-grotesk would fight it. The replacement needs to read as warm-geometric, not corporate-neutral.
- **The display character is expendable.** Bricolage Grotesque's expressive variable axes give Calm its current display flavour. Losing that is a real cost, but it is outweighed by consistent Latin + Cyrillic rendering from one family.

## Decision

Replace both `font.display` and `font.body` with **Manrope** — a single variable super-family (weights 200–800) with full Latin + Cyrillic coverage:

```diff
 "font": {
-  "display": "\"Bricolage Grotesque\", sans-serif",
-  "body":    "\"Spline Sans\", sans-serif"
+  "display": "\"Manrope\", sans-serif",
+  "body":    "\"Manrope\", sans-serif"
 }
```

- **Display role**: Manrope at the heavier end of the axis (700–800) for headings — reads as a confident display face without Bricolage's quirk.
- **Body role**: Manrope at the lighter end (400–500) for running text — even metrics across Latin and Cyrillic, no fallback chain, no mixed x-heights.
- **Warmth**: Manrope's geometric-but-rounded character pairs naturally with the sage/clay palette; it is deliberately warmer than the cold mainstream neo-grotesks.
- **One family to bundle and load**, not two — simpler asset pipeline, single weight-axis mapping, guaranteed role/script consistency.

### Downstream edits (consequences of this decision, applied per the design sync rule)

- `design/themes/calm/tokens.json` — update `font.display` and `font.body` (the edit above).
- `design/themes/calm/bindings/tokens.css` — mirror the change (worn by the Keycloak `lifeos` login theme).
- `apps/wallet/lib/app/theme/calm_tokens.dart` — update the `fontDisplay` / `fontBody` constants and **bundle the Manrope variable font asset** (today no Calm font is bundled, so this also turns "family name declared but falling back" into "family actually shipped"). Specific bundling / weight-axis config is deferred — see below.

## Consequences

Positive:

- The Spline Sans Cyrillic gap is closed completely — no fallback fonts, no mixed metrics, no per-script visual mismatch.
- A single family across display + body simplifies bundling, loading, and the binding surface; one weight axis instead of two families.
- Trivially extensible to future Cyrillic locales (Belarusian, Ukrainian) — the script coverage is already there.
- Login and app stay visually consistent: the CSS binding (Keycloak) and the Dart binding (Wallet) both swap, so the Russian sign-in page and the Russian app wear the same typeface.

Negative:

- **Calm's display character shifts.** Bricolage Grotesque's expressive variable axes are gone; headings lose their distinctive quirk. Accepted as the cost of Latin + Cyrillic consistency.
- **Existing mockups and screenshots are stale** the moment the swap lands — the design HTML under `apps/wallet/docs/design/` and the Keycloak theme reference Calm's old display face and will need refreshing when the bindings are updated.
- **Bundling a variable font is new work.** Until now no Calm font shipped at all; this decision requires actually adding the Manrope variable TTF to `pubspec.yaml` and wiring the weight axis, plus the equivalent font-face declarations in the CSS binding.

Neutral:

- Manrope's weight range (200–800) is wider than Calm's current `fontWeight` tokens (400/500/600/700). The extra range is available for display use but the named tokens stay as-is.
- The `sans-serif` fallback in each token remains the last resort; with the asset bundled, it is reached only if the font fails to load.

## Alternatives Considered

1. **Keep Spline Sans + rely on the platform Cyrillic fallback chain.** Rejected: mixed font metrics produce uneven line heights and visible glyph-style mismatches between Latin and Cyrillic in the same paragraph, worst in body text (the 95% case). It reads as "this app wasn't designed for my language" — the exact impression a localized personal-finance app must avoid.
2. **Keep Bricolage Grotesque for display; swap only the body font for a Cyrillic-capable face.** Rejected: two-family rendering still crosses the display/body seam with different metrics, and doubles the bundling surface. A single variable super-family gives cleaner rendering and a simpler story.
3. **Inter (or Inter Display) instead of Manrope.** Rejected as the default: Inter is the safe mainstream neo-grotesk but reads colder than Calm's warm sage/clay palette warrants. Manrope's geometric warmth fits the theme. Inter remains a defensible fallback if Manrope's weights prove insufficient in practice.
4. **A Cyrillic-extended Bricolage Grotesque pairing.** Rejected: preserves the display character but keeps two families and still needs a Cyrillic-capable body — strictly more complexity than the single-family decision for no rendering gain.

## Deferred sub-decisions (captured, non-blocking)

- **Manrope font bundling specifics** — which variable TTF(s), the `pubspec.yaml` asset entries, and the weight-axis → `FontWeight` mapping. Deferred to the implementation of this swap; decided only that the variable font is bundled (not a static-weight subset).
- **`tokens.dart` / `tokens.css` regeneration pipeline (Style Dictionary).** Still deferred until a second binding or font change makes hand-mirroring costly (unchanged from the existing design README stance). This swap is a manual mirror.
- **Refresh of design mockups and the Keycloak theme reference** under the new face — done when the bindings are updated, not as part of the decision text.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
