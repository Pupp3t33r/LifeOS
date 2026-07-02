# Home — design mockups

Static HTML mockups from the Home functional/visual design pass (2026-06-29). They are the visual companion to the decisions frozen in **[Wallet ADR-0002](../../adr/0002-navigation-and-information-architecture.md)** (navigation + the current-period cockpit) and **[Wallet ADR-0003](../../adr/0003-category-colour-system.md)** (category colours). The narrative summary lives in [`apps/wallet/PLAN.md` §13](../../../PLAN.md).

These are **design references, not app code.** The real screens are built in Flutter against the Calm tokens (`lib/app/theme/calm_tokens.dart`) and the Money API (`MonthProjection`, ADR-0007). Where a mockup and the ADRs disagree, the ADRs win.

> **Reflected in the mockups (shipped behaviour):**
> - **Period switcher** — `‹ Month YYYY ›` chevrons + an **Active / Planning / Past** status chip + a snap-back-to-**Current** pill; the cockpit always reopens on the active period. Shown in `cockpit-final.html`.
> - **Future ("Planning") periods** render planning-only per ADR-0023: the worklist is a read-only **preview** and the one-off **Add** verb is disabled (a one-off is always a dated-today actual, so it can't file into a future period). Noted on the switcher in `cockpit-final.html`.
> - **Onboarding** — single centred column (the misleading "savings canvas" preview was dropped): [`../onboarding/onboarding.html`](../onboarding/onboarding.html).
> - **Settings** — searchable, grouped page (Appearance / Money / Security): [`../settings/settings.html`](../settings/settings.html).

## Viewing

Each file is self-contained (Calm palette inline as CSS variables; Bricolage Grotesque + Spline Sans from Google Fonts). Open via any static server — `file://` is blocked by the fonts/CDN, so serve the folder:

```bash
cd apps/wallet/docs/design/home
python -m http.server 8000
# then open http://localhost:8000/cockpit-final.html
```

Rendered screenshots (light mode, desktop + phone) are in [`screenshots/`](./screenshots) for quick viewing without a server.

## The files

| File | What it shows | Screenshot |
|---|---|---|
| **[cockpit-final.html](./cockpit-final.html)** | **The build target.** Home as the current-period cockpit, everything wired: Home·Activity·Accounts·Wishlist nav, period switcher, reactive on-track strip + budgets expand, the Upcoming/Logged worklist with the Status/Type toggle, container rows with category proportion bars (one expanded to its lines), pinned rates, Close. Desktop + phone. | — (serve the HTML) |
| **[rows-final.html](./rows-final.html)** | The **row spec**: `icon · name · [proportion bar + count] · amount`, the expand rule, and the two special cases (single-item; multi-item/single-category). Light + dark. | [png](./screenshots/rows-final.png) |
| **[categories.html](./categories.html)** | The **12-colour Calm palette** (light + dark) and the **Settings → Categories** page — swatch picker, recolourable system categories, and how the colours read on the canvas. | [png](./screenshots/categories.png) |
| **[home-options.html](./home-options.html)** | **Design history — rejected.** The three stats-first directions explored first (Ledger / Verdict / Waterfall) before Home was reframed as an operational cockpit. Kept to record *why* the cockpit won over a readout. | [png](./screenshots/home-options.png) |

## The short story

1. Home was first explored as a **stats readout** (`home-options.html`) — ledger, verdict, waterfall. All rejected: a planner's daily job is *operating* the month, not reading a number.
2. Reframed as the **current-period cockpit** — switch periods, confirm what's paid, buy planned items, log expenses, close. Stats demoted to a reactive strip + a budgets expand.
3. "Plan" dissolved as a destination (its instances live on Home; its definitions are edited in context); the freed slot went to **Wishlist** (which grows into Inventory/Net-worth in Phase 3).
4. Worklist groups by realized status — **Upcoming / Logged** (projected vs. actual, ADR-0007/0026) — with a by-type toggle. No "must-pay/maybe" intent (none exists in the model); no by-category grouping (entries are containers, category is per-line, ADR-0019).
5. Rows are containers with a **category proportion bar**, which required a curated colour system → the 12-colour palette + Settings → Categories (`categories.html`, ADR-0003).
