# Wallet — design artifacts

Static design references for the Wallet app. These are **prototypes**, not shipped
code — the Flutter implementation under `lib/` is the source of truth.

## `onboarding-prototype.html`

The "Set up your first month" onboarding flow (see Money [ADR-0013](../../../services/money/docs/adr/0013-user-preferences-and-configurable-month.md)).
A self-contained, responsive HTML mock grounded in the **Calm** theme tokens
(`design/themes/calm/tokens.json`). Open it directly in a browser.

What it pins down for the Flutter build:

- **Three steps** — savings account (name / currency / opening balance) → month
  start (calendar vs. a chosen day, 1–31 slider with last-day clamp note and the
  lock-after-first-close caveat) → optional target savings.
- **The "living canvas"** — a persistent preview (right on wide screens, top on
  phones) that updates as you answer and shows **honest empty states**
  ("after setup", "needs income & bills", "not set yet") rather than faking numbers.
- **Responsive** — single column on phones, two columns at `min-width:900px`.
- **Deep-linkable** for review: `?step=N&mode=custom&day=D`.

Dark mode is handled; brand-button label color flips to dark ink on the lighter
dark-mode sage (mirrored in the real theme — see `lib/app/theme/app_theme.dart`).
