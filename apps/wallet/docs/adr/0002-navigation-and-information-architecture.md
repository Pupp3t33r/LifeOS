# ADR-0002: Navigation & information architecture — the current-period cockpit and a four-destination shell

## Status

Accepted

Date: 2026-06-29

**Supersedes:** the tentative navigation sketch in [`apps/wallet/PLAN.md` §13](../../PLAN.md) (the "Plan: merged vs. split" and "adaptive nav model" open threads are resolved here).

**Relates to:** [Money ADR-0007](../../../../services/money/docs/adr/0007-monthly-review-and-projection.md) (`MonthProjection` — the on-track figures), [ADR-0016](../../../../services/money/docs/adr/0016-accounting-period-flow-ledger.md)/[ADR-0018](../../../../services/money/docs/adr/0018-planned-purchases-on-accounting-period.md)/[ADR-0019](../../../../services/money/docs/adr/0019-universal-line-items.md) (period, planned purchases, line-items), [ADR-0023](../../../../services/money/docs/adr/0023-active-month-model.md) (multiple open periods), [ADR-0024](../../../../services/money/docs/adr/0024-category-model.md) (managed categories), [ADR-0025](../../../../services/money/docs/adr/0025-budget-period-centric-and-category-targeted.md) (budgets), [ADR-0026](../../../../services/money/docs/adr/0026-actuals-honesty-and-savings-movements.md) (actual = Σ flows), [ADR-0010](../../../../services/money/docs/adr/0010-asset-aggregate.md) (Asset — Phase 3), [ADR-0015](../../../../services/money/docs/adr/0015-fx-rate-sourcing-and-client-cache.md) (rates), [ADR-0021](../../../../services/money/docs/adr/0021-close-flow-multi-account-allocation-and-dispositions.md) (close), [ADR-0013](../../../../services/money/docs/adr/0013-user-preferences-and-configurable-month.md) (preferences), [ADR-0014](../../../../services/money/docs/adr/0014-auth-session-lifetimes-and-passkeys.md) (auth/app-lock). Drives [Wallet ADR-0003](./0003-category-colour-system.md) (the row/budget colours).

## Context

The Wallet is a personal-finance **planner**, not a tracker (PLAN §1). The hard question before building the main screen was *what the app's navigation is and what Home actually does*. Two findings shaped this ADR.

First, **Home is not a readout.** Early exploration treated Home as the "savings canvas" — a stats hero (target / projected / on-track). But day to day the user opens the app to *operate the current period*: switch months, confirm what was paid, drop in an expense, move a wishlist item into the month, close out. A stats hero is glanced at and left; the planner needs a surface you work in. The on-track number still matters — but as a *consequence* of the work, not the headline.

Second, the **"Plan" page dissolves.** The tentative IA (PLAN §13) had four primary pages — Home / Plan / Activity / Accounts — where "Plan" held the projection levers (recurring, wishlist, budgets). Once Home becomes the cockpit, the *instances* of those levers surface there (recurring occurrences as the confirm checklist; planned purchases as buy-rows; budgets as the on-track expand), and their *definitions* are naturally edited in-context. What remains needing a home of its own is the **wishlist backlog** — a browseable list (with packages, Money ADR-0022) that is also the front door to the Phase-3 possessions/net-worth view (Money ADR-0010).

Forces at play:

- **Multiplatform from day one** (PLAN §4): Android, Web, Windows, Linux — both phone-portrait and desktop/web-landscape. The shell must adapt across that range, not assume a phone.
- **The app already has an adaptive `StatefulShellRoute` shell** (`lib/app/navigation/app_shell.dart`, `app_router.dart`) with bottom-bar / rail / extended-rail breakpoints. This ADR sets the *destination set* and *Home's content*, not the shell mechanism (which exists).
- **Multiple periods can be open** (Money ADR-0023): future periods accept planning only; actuals route by date; the "active" period is UI focus. Home must make the active period switchable and obvious.
- **The model has no priority/intent flag.** There is deliberately no "must-pay vs. maybe" field (Money ADR-0017/0018/0026). Any grouping of the worklist must derive from structure that already exists, never from an invented intent.
- **Entries are containers; categories live on lines** (Money ADR-0019/0024). A single entry can span multiple categories, so entries cannot be grouped or single-coloured by category.

## Decision

### The shell — four destinations, adaptive chrome

The authenticated app is a persistent shell wrapping **four** primary destinations:

> **Home · Activity · Accounts · Wishlist**

"Plan" is **not** a destination (see *Plan dissolves* below). The shell chrome adapts to width (the existing breakpoints): a bottom `NavigationBar` on phone-portrait (`<720`), a `NavigationRail` at mid widths (`720–1240`), and an extended labelled sidebar rail on desktop/web-landscape (`≥1240`). **Settings** is a full-screen route *above* the shell, reached from the app-bar gear — not a nav slot.

### Home is the current-period cockpit

Home is a surface you operate, not a stats page. Top to bottom:

1. **Period switcher** — `‹ Month YYYY ›` with the period span and an **Active** badge; peeks at other open periods (Money ADR-0023). Switching changes the period in focus.
2. **On-track strip** — a thin, reactive band: `on track ±X`, a slim projected-vs-target bar, and `details ▾`. It is the *only* persistent stats, and it reacts as the user acts (confirm a bill, add a purchase → it shifts). Sourced from `MonthProjection` (Money ADR-0007).
3. **Budgets (the `details ▾` expand)** — per-category budget progress bars (Money ADR-0025), shown inline. This is the "where is it going" layer; it is *why* a separate Plan/budgets page is unnecessary.
4. **The worklist** — the bulk of the screen (see grouping + rows below).
5. **Add-flow FAB** and the **Close** entry (the close wizard launches when the period is ready, Money ADR-0021/0026).

### Worklist grouping — by realized status, with a by-type toggle

The **default** grouping is the app's own spine, *projected vs. actual* (Money ADR-0007/0026):

- **Upcoming** — items that are *not yet a flow*: recurring occurrences (confirm) **and** planned purchases (buy), intermixed. The row **icon** carries the verb (a confirm checkbox vs. a "buy" bag), not a section split.
- **Logged** — the actuals: `Σ flows` recorded this period.

Confirming/buying an Upcoming item records a `FlowRecorded` (Money ADR-0017/0018), so it moves from Upcoming → Logged. A **by-type toggle** offers the alternative cut — **Recurring / Planned / Ad-hoc** (record type) — for users who prefer stable, type-grouped lists.

Two groupings are **explicitly rejected**: by "must-pay vs. maybe" (no such field exists, and we will not invent one) and by category (entries are containers; category is per-line — Money ADR-0019). Category *as a lens* lives where it belongs: the budgets expand (summed) and Activity (filter/group the flat log).

### Rows are containers

Every worklist row represents an **entry** (a container of `Line`s, Money ADR-0019) and shares one anatomy:

> `icon · name · [proportion bar + count] · amount`

- **Multi-line** → a chevron; the proportion bar shows the category split; count reads "N items"; tapping expands to per-line rows (`category dot · name · category · amount`).
- **Multi-line, single category** → a solid bar; count reads "N items · Category"; still expandable.
- **Single line** → a solid bar; **no count** (shows the **category name**); **no chevron** — there is nothing to reveal, so a tap opens edit.

The proportion-bar and dot colours come from [Wallet ADR-0003](./0003-category-colour-system.md).

### Plan dissolves; Wishlist takes the fourth slot

There is no Plan page. Its contents are redistributed:

- **Recurring rules** — met as the Upcoming checklist on Home; the *rule* is edited in-context from its row.
- **Budget targets** — viewed in Home's budgets expand; edited there or in Settings.
- **Wishlist** — the browseable backlog becomes the fourth destination. "Plan from wishlist" on Home pulls items into the active period. In Phase 3 the Wishlist destination grows a second lens — Inventory / Net worth — as the Asset aggregate ships (Money ADR-0010); it is designed now so it can absorb that without rework.

### Non-page surfaces

- **Rates** (Money ADR-0015) — a panel/curtain pulled up where conversions appear (the on-track total, the accounts/rates glance). On desktop, a pinned-rates card may sit in the side rail under Accounts; on phone it stays behind the curtain. Not a page.
- **Close month** (Money ADR-0021/0026) — a wizard launched from Home.
- **Add flow** — a quick-add sheet (the FAB); the recorded flow lands in Activity / Home's Logged.

### Settings

A full-screen route above the shell, holding: locale (Wallet ADR-0001), theme, app-lock & passkey enrollment (Money ADR-0014), display currency & month-start (Money ADR-0013), **Categories** management including colour (Money ADR-0024 + Wallet ADR-0003), and rates pinning (Money ADR-0015).

## Consequences

Positive:

- Home matches how the app is actually used — operate the month — with stats present but demoted to a reactive strip, so actions visibly move the number.
- Four destinations fit a phone bottom bar comfortably and scale up to a desktop sidebar.
- Resolves PLAN §13's two open threads: "Plan merged vs. split" (dissolved) and the adaptive nav model (codified).
- The possessions axis gets a real home (Wishlist → Inventory/Net worth) instead of being stranded.
- Grouping and row colour rest on structure that already exists (record type, per-line category), inventing no new domain state.

Negative:

- The shell's current destination set in code is Home / Plan / Activity / Accounts; this ADR replaces **Plan with Wishlist**, a build change (router branch, shell destination, l10n keys).
- "Edit the recurring rule in-context" spreads definition-editing across the app rather than centralizing it on a Plan page; discoverability of *all* recurring rules at once needs a deliberate entry (e.g., from Settings or a Wishlist/Plan-adjacent list).
- The default Upcoming/Logged grouping makes rows relocate on confirm; mitigated by the by-type toggle for users who dislike the movement.

Neutral:

- Activity overlaps Home's "Logged this month"; it is kept as the cross-period, filterable log (Home shows only the active period). Whether Activity later folds into a Home "view all" is left open.
- The adaptive breakpoints (720 / 1240) are inherited from the existing shell and may be tuned during build.

## Alternatives Considered

1. **Stats-first Home (the savings-canvas hero).** Rejected: a readout is glanced at and left; the planner's daily job is operating the period. Stats are kept as a reactive strip + budgets expand, not the headline.
2. **Keep Plan as a destination** (one merged page, or split into Recurring/Wishlist/Budgets). Rejected: the cockpit absorbs the instances and in-context editing covers the definitions; only the wishlist backlog needs its own page, which it now gets.
3. **Group the worklist by "must-pay vs. maybe."** Rejected: no such intent is tracked, and we will not add one. The free, model-grounded cut is realized-status (Upcoming/Logged); record type is the toggle.
4. **Group/colour rows by category.** Rejected: entries are containers spanning multiple per-line categories; there is no single category to group or colour an entry by. Category is a line-level lens (budgets expand, Activity).
5. **Five or more destinations** (e.g., separate Recurring, Budgets). Rejected: overflows a phone bottom bar and fragments surfaces the cockpit already unifies.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
