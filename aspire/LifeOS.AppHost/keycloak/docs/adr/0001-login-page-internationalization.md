# ADR-0001: Login page internationalization — English + Russian

## Status

Accepted

Date: 2026-06-29

**Relates to:** [Money ADR-0004](../../../../../services/money/docs/adr/0004-zero-trust-jwt-validation.md) and [Money ADR-0014](../../../../../services/money/docs/adr/0014-auth-session-lifetimes-and-passkeys.md) (the platform's auth-decision lineage, housed in Money). This is the first ADR in the Keycloak-scoped folder; it covers the **hosted login/account UI**, not service-side token handling.

## Context

LifeOS fronts authentication with Keycloak (realm `lifeos`, single issuer via the Gateway). The login surface is a custom `lifeos` login theme: `template.ftl`, `login.ftl`, custom CSS, a dark-mode toggle, and exactly **three** custom message keys (`loginAccountTitle`, `loginSubtitle`, `doLogIn`). Every other string on the page (`password`, `rememberMe`, `doForgotPassword`, `email`, …) comes from Keycloak's parent `keycloak` login theme.

Forces at play:

- **The primary user is in Belarus** ([Money ADR-0015](../../../../../services/money/docs/adr/0015-fx-rate-sourcing-and-client-cache.md) records this for FX sourcing). Russian is the day-to-day language; English is the development and default language. A login page only in English is a daily papercut for the actual user.
- **The custom theme overrides only three strings.** Keycloak's parent theme already ships translations for all built-in login strings in many locales, **including Russian**. So localizing this theme means translating *three keys*, not re-translating the whole login UI — the bulk is inherited for free.
- **The locale switcher already exists but never renders.** `template.ftl` (the `#if realm.internationalizationEnabled && locale.supported?size gt 1` block) already lists `locale.supported` with `${l.label}` and styles it (`.locale` in `styles.css`). It was dormant because the realm had no i18n configured.
- **State before this ADR:** `theme.properties` declared `locales=en`; only `messages_en.properties` existed; `lifeos-realm.json` had **no** `internationalizationEnabled` / `supportedLocales` / `defaultLocale`, so Keycloak i18n was off and the switcher never appeared.
- **This is an identity concern, not a service concern.** Which languages the *login page* offers is owned by Keycloak, independent of any service. It is also independent of in-app (Wallet) localization, which is a separate, larger effort.

## Decision

Enable internationalization on the Keycloak login surface for **English and Russian**, with English as the default.

1. **Realm** (`lifeos-realm.json`): set `internationalizationEnabled: true`, `supportedLocales: ["en", "ru"]`, `defaultLocale: "en"`.
2. **Theme** (`themes/lifeos/login/theme.properties`): declare `locales=en,ru`.
3. **Messages** (`themes/lifeos/login/messages/messages_ru.properties`): translate the three custom keys to Russian. All built-in strings inherit from the parent theme's Russian bundle — we do not copy them.

English remains the default; the user switches via the now-rendering locale switcher (Keycloak persists the choice in its `KC_LOCALE` cookie and honors `?kc_locale=`). The `${l.label}` values (`English`, `Русский`) come from the base theme.

**Scope:** this ADR covers only the Keycloak-hosted login/account pages. **In-app Wallet (Flutter) localization is explicitly out of scope** and is not decided here — it is a separate concern the Wallet owns, and no ADR for it exists yet. Adding a third login locale later is a drop-in (`supportedLocales` += the tag, `locales` += the tag, add `messages_<tag>.properties`); no decision is needed to do so.

## Consequences

Positive:

- The actual user gets a Russian login with the smallest possible surface to maintain — three translated keys; everything else is inherited from Keycloak.
- The dormant locale switcher now works as designed; no template or CSS change was needed.
- English stays the default, so development, screenshots, and docs are unaffected.
- One realm-config change yields the behavior; fully reversible.

Negative:

- **Dev realm import gap (same as [Money ADR-0014](../../../../../services/money/docs/adr/0014-auth-session-lifetimes-and-passkeys.md) and `PLAN.md §8`):** editing `lifeos-realm.json` does **not** apply to an already-running Keycloak with a persistent Postgres volume — realm import skips an existing realm. Applying this needs the admin API, a realm re-import, or a volume reset.
- The three custom Russian strings must be kept in sync whenever the English copy changes — a small, manual coupling.
- Built-in string quality/coverage for Russian is owned by Keycloak's parent theme, not us; a gap there would surface untranslated keys we don't control.

Neutral:

- Russian was chosen over Belarusian as the day-to-day language; Belarusian (or any other locale) can be added later with no new decision (see Scope).
- The `money-api` and other clients are unaffected — locale is a login-UI concern only.

## Alternatives Considered

1. **English only (status quo).** Rejected: the primary user is Russian-speaking; an English-only login is a daily friction point.
2. **Hand-translate the entire login UI inside the custom theme.** Rejected: unnecessary. The parent theme already localizes every built-in string; translating the three custom keys is the whole job.
3. **Belarusian instead of / in addition to Russian.** Rejected for v1: Russian is the user's day-to-day language and has full parent-theme coverage. Belarusian is a zero-decision drop-in later if wanted.
4. **Record this in Money's ADR folder** (alongside 0004/0014). Rejected: login-page language is a Keycloak/identity decision, not Money-specific — this is the founding reason for this Keycloak-scoped folder. The pre-existing 0004/0014 remain in Money (frozen, cross-linked from this folder's README) rather than being rewritten.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
