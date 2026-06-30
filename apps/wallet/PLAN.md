# Wallet App — Plan

> **Purpose:** This file is the evolving roadmap for the Wallet Flutter app. It captures the full phased vision (Phase 1–5), v1 scope, deferred work, and key design decisions. It is **not** frozen (unlike ADRs). Update freely as work progresses.
>
> **Related:** [Wallet AGENTS.md](./AGENTS.md) for stable conventions; [Money PLAN.md](../../services/money/PLAN.md) for the backend roadmap that drives Wallet work.

---

## 1. App vision

Wallet is a **personal-finance planner**, not a tracker. Its primary job is answering *"what does this month look like financially?"* — not *"what is my current balance?"*

The core mental model is the **savings canvas**:

```
   ┌─────────────────────────────────────┐
   │           March 2026                │
   │                                     │
   │   Projected income      +$4,200     │
   │   Projected spending    -$2,650     │
   │   ─────────────────────────────     │
   │   Planned purchases      -$300      │
   │   ─────────────────────────────     │
   │   Projected savings      +$1,250    │
   │   Your target           +$1,000 ✏️   │
   │   ─────────────────────────────     │
   │   On track by            +$250      │
   │                                     │
   └─────────────────────────────────────┘
```

Two levers the user pulls:
1. **Target savings** — "I want to save \$1,000 this month."
2. **Planned purchases** — Wishlist items moved into "buy this month."

The app shows the consequence: dropping a \$800 lens into March drops projected savings to +\$450, below the \$1,000 target. The user decides; the math is honest.

---

## 2. The three-layer savings model

| Layer | Source | Purpose |
|---|---|---|
| **Target savings** | User-set goal per month | "I want to save \$1,000 this month." |
| **Projected savings** | Computed: `income − spending − planned_purchases` | "Based on what I've planned, I'm on track for \$1,250." |
| **Actual savings** | `Σ flows` incl. an optional `UnaccountedFlowRecorded` gap entry (Money ADR-0026) | "In reality I saved \$1,180 — accounts for the coffees I didn't log." |

The honesty valve is an **`UnaccountedFlowRecorded` gap entry** (Money ADR-0026): the user's real number is stored as a signed flow entry (the gap between logged and actual), so **actual = Σ flows** always and the ledger stays complete. (The old `ActualSavingsOverride` god-number is removed.) This lets the planner tolerate gaps in transaction logging without forcing the user to itemize every coffee.

- Power-user mode: log everything → projected converges with actual → no gap entry needed.
- Big-picture mode: log only big things → projected drifts → user enters actual at month-end (a gap entry is recorded for the difference).

Both styles work without the app shaming either. Transactions are **frequency-up-to-user**: a user can log every coffee or log nothing and rely on a gap entry at close.

---

## 3. Design principles

1. **Planner, not tracker.** Home is the savings canvas. Transactions are demoted to optional actuals that refine projections.
2. **Multi-currency from day one.** Money (the value object) is `Money { Amount, Currency }`. The user has multiple savings accounts in different currencies. The canvas aggregates to a display currency; line items render as "original + converted inline" (€80 (~\$86)).
3. **Honesty valves everywhere.** Target savings, actual savings override, savings account balance override, asset estimated value — user-truth beats computed-truth wherever a real number matters.
4. **No false precision.** Don't display a balance the user can't verify. Don't imply the app knows what it doesn't. The actual-override is the explicit acknowledgment of this.
5. **Solo-first, family-aware.** v1 is single-user. The data model carries `OwnerId` everywhere so adding family UX later is a UI concern, not a migration.

---

## 4. Phase 1 — Solo planner (v1 scope)

### Platforms

Android, Web, Windows, Linux. (macOS/iOS technically free; not prioritized.)

### Screens

| Screen | Job | Backend (Money) |
|---|---|---|
| **Month overview (Home)** | Savings canvas: target / projected / actual; planned purchases summary; recent activity preview | `MonthProjection` (ADR-0007) |
| **Recurring editor** | Engine of projections: known income, bills, subscriptions, installments | `RecurringPayment`, `InstallmentPlan` (ADR-0005) |
| **Wishlist + planned purchases** | What you want vs. what fits this month; convert-to-PO action | `WishlistItem`, `PurchaseOrder` (ADR-0005) |
| **Transactions log** | Optional actuals — record what really happened, used to refine projections | `TransactionRecorded` (ADR-0005) |
| **Light budgets** | Per-category spend targets; actuals plugged in when logged | `Budget` (ADR-0006) |
| **Savings accounts** | List of accounts with balances (override-enabled); create/edit | `Account` (ADR-0005, ADR-0009) |

### Out-of-scope for v1

- Domain-linked purchases (Phase 2: Books, Board Games deep-linking)
- Inventory & net worth (Phase 3: Asset aggregate)
- Family UX (Phase 4)
- Long-term analytics, year review, reports (Phase 5)
- Voice/photo receipt capture (depends on Document Processing service)
- Bank/SMS auto-import (out of scope indefinitely unless a forcing function arrives)
- Savings goals (named allocation pools) — Wishlist already serves this purpose

### Backend prerequisite

v1 requires the full Phase 1 Money backend (see [Money PLAN.md](../../services/money/PLAN.md) §3). Sequencing is **backend-first**: Money features land, then Wallet UI is built against the real API. No mock/stub parallel track in v1.

### Auth & first-run (Money [ADR-0014](../../services/money/docs/adr/0014-auth-session-lifetimes-and-passkeys.md))

- **First-run onboarding** *(built)* — "Set up your first month": first savings account + display currency + configurable month start day (Money ADR-0013). The router gates on `UserPreferences.DisplayCurrency` being null; responsive (two-column wide / stacked phone) with a live "savings canvas" preview.
- **Per-platform session scope** *(built)* — requests `offline_access` on native/desktop only, omits on web (`AuthConfig.scopes` gated on `kIsWeb`). Native gets a long offline session (idle 60d / max 180d); web a short online session (idle 30m / max 24h). One realm config, split by scope.
- **Biometric app-lock** *(built, native only)* — via `local_auth`: required on cold start, re-lock after ~5 min in background, user-configurable (default on); optional toggle shown in onboarding only where the device supports it. The lock screen always offers **"Use password"** and **"Log out / sign in as a different account."** No-op on web. On-device biometric prompt pending manual verification.
- **Passkey login** *(built, web-verified)* — WebAuthn/FIDO2 as the preferred Keycloak login method, **password always available as fallback** (bootstrap + recovery). On Keycloak 26.4+ enabling `webAuthnPolicyPasswordlessPasskeysEnabled` auto-integrates passkeys (conditional + modal UI) into the default browser flow — no custom flow JSON needed. The custom login theme's `template.ftl` must include the `rfc4648` import map the base theme provides, or the WebAuthn ES modules fail silently ("Failed to resolve module specifier rfc4648") and `navigator.credentials.create/get` never runs. Verified end-to-end via a Chrome virtual authenticator: enrollment (alice is seeded with the `webauthn-register-passwordless` required action → registers a passkey, password fallback retained) and passkey-only login (conditional-UI autofill → auth code, no password).

#### Auth — remaining / revisit later

Auth is **dev-complete and verified** as of 2026-06-26. None of the below are blockers; they are on-device checks that need real hardware, one optional UX, and deployment-phase hardening. Pick up here when able.

- [ ] **On-device biometric app-lock prompt** *(manual verify)* — the `local_auth` flow is proven as a web no-op; the real fingerprint/face prompt on a native device is untested.
- [ ] **Native / platform passkey authenticator** *(manual verify)* — passkey enrollment + passwordless login verified on web with a virtual authenticator; a real device/platform authenticator is untested.
- [ ] **In-app passkey enrollment deep-link** *(optional UX)* — the enrollment *mechanism* works (Keycloak `webauthn-register-passwordless` required action / Account Console); surface it from Wallet settings as the in-app opt-in ("A+B").
- [ ] **Prod hardening** *(deployment phase)* — real WebAuthn RP ID (passkeys currently assume `localhost`); Postgres-backed Keycloak DB (dev uses an H2 data volume); real secrets (not `devsecret` / `admin`/`admin`); brute-force protection (currently `bruteForceProtected: false` in the dev realm).

---

## 5. Phase 2 — Domain-linked purchases

When Books and Board Games services come online:

- Wishlist and PO flows gain the `{ serviceType, externalId }` link to real domain objects.
- Categories auto-populate from domains (`books`, `board-games`).
- Wallet deep-links to the relevant domain app (or shows an inline preview via Gateway BFF composition).
- No new Wallet feature modules per se — the existing wishlist/PO UI becomes "richer" when a domain is linked.

The Phase 1 data model already supports this via `ExternalReference`; Phase 2 is UI work, not schema migration.

---

## 6. Phase 3 — Inventory & net worth

- **Money Asset aggregate** (ADR-0010) ships. Two ingestion paths:
  - *Tracked:* PO advances to Received → `AssetTracked` event.
  - *Pre-existing import:* user adds directly with `AcquiredDate`, `AcquiredCost`, `CurrentEstimatedValue`. Bypasses MonthlyReview entirely.
- New Wallet screen: **Inventory** — list of owned Assets with values; edit `CurrentEstimatedValue`; mark for sale; record sale.
- New Wallet screen: **Net worth** — savings balances + asset values − outstanding installment balances, all in display currency.
- Gateway BFF endpoint `GET /app/v1/inventory` enriches Asset rows with descriptive data from Books/Board Games (title, cover) for display. Math never depends on enrichment.
- **Bought-for vs sold-for stat:** computed on sold Assets — `SoldFor − AcquiredCost`, both converted via ADR-0008.

---

## 7. Phase 4 — Family / multi-user

- Shared savings accounts with permissions.
- His / hers / ours tagging on transactions and POs.
- Per-user budgets.
- Family-level net worth view.
- The data model already carries `OwnerId` (ADR-0004); Phase 4 is primarily UI + permission enforcement, not schema migration.

---

## 8. Phase 5 — Long-term analytics

- Year+ trends: savings rate, category spend, net-worth trajectory.
- "Should I buy this over time?" advisor: project impact of a deferred purchase on savings trajectory.
- Multi-month recurring review.
- All read-only views over existing data — no new aggregates expected.

---

## 9. Cross-cutting decisions (already settled)

| Topic | Decision | Source |
|---|---|---|
| App structure | Money-only app now, others later (no unified LifeOS shell) | User decision |
| Platforms | Android, Web, Windows, Linux | User decision |
| State management | Riverpod | User decision |
| API client | OpenAPI codegen (dart-dio) from Money's `/openapi/v1.json` | User decision |
| BFF routes | Gateway `/app/v1/*` (renamed from `/mobile/v1/*`) | Gateway AGENTS.md |
| Offline model | Read models + pending-operations outbox in drift. No client-side event sourcing. | User decision |
| Family stance v1 | Solo only; data model family-aware | User decision |
| Categories | Managed list: system (Books/Board Games/Video Games) + user categories; one `CategoryId` per line; no tags | Money ADR-0024 |
| Budgets v1 | Light, per-period, no envelopes, no rollover; Marten document; targets a `CategoryId` | Money ADR-0025 (supersedes 0006) |
| Savings model | Three-layer: target / projected / actual (`Σ flows` incl. an `UnaccountedFlowRecorded` gap entry) | Money ADR-0007 + ADR-0026 |
| Multi-currency | In v1 with FX service (Frankfurter) | Money ADR-0008 |
| Accounts | Savings only; one currency per account | Money ADR-0009 |
| Inventory architecture | Asset aggregate inside Money, financial fields only | Money ADR-0010 |
| Income pattern | Stable + resale (later); planner accommodates variable | User decision |
| Subscriptions | Modeled as a `RecurringPayment` (optionally given a user category); not a distinct concept | Money ADR-0017 |
| Auth session & login UX | Per-platform token lifetimes; passkey-preferred + password fallback; native biometric app-lock; short web session | Money ADR-0014 |

---

## 10. Open implementation questions

These can be settled during implementation, not before:

- FX display formatting edge cases (how many decimals, when to suppress the original).
- Whether month-close auto-creates the savings transfer transaction or requires explicit user confirmation in the close flow.
- Wishlist → planned-purchase conversion: drag-and-drop vs. button-driven; whether to allow partial (split a wishlist item across months).
- The `UnaccountedFlowRecorded` gap entry is a single display-currency amount (Money ADR-0026); whether a per-currency breakdown is ever needed is deferred.
- Savings-account creation flow specifics (default currency, opening balance source).
- Web-specific UX (responsive layout, mobile-vs-desktop affordances).

---

## 11. What Wallet will NOT do (anti-scope)

- ❌ **Bank integration.** No Plaid, no SMS parsing. All data is user-entered or server-projected.
- ❌ **Tax handling.** No tax categorization, no export to tax software. Out of scope indefinitely.
- ❌ **Investment tracking.** Stocks, crypto, etc. are not in scope. Money is for cash savings, planned spending, and physical/digital asset resale values only.
- ❌ **Credit score / financial product recommendations.** Not a fintech app.
- ❌ **Budget enforcement / spend-blocking.** Budgets are advisory; the planner shows over-spend visually but never prevents it.
- ❌ **Multi-user real-time collaboration.** Phase 4 is sequential family UX (his/hers/ours tagging), not concurrent edit.

---

## 12. Design backlog — open items (as of 2026-06-27)

A multi-session functional-design pass is underway (pages & flows before UI/UX). Status:

### Landed 2026-06-26 (Money ADRs)
- **ADR-0015** — FX rate sourcing: Belarusbank card **SELL** rates (primary) + Frankfurter (fallback); plain hourly `BackgroundService`; client **15-min** rate cache; in-app **Rates view**. Amends ADR-0013 with `DefaultSpendingCurrency`.
- **ADR-0016** — **`AccountingPeriod`** aggregate (renames `MonthlyReview`): one per-month stream holding lifecycle **+** the flow ledger (`FlowRecorded` / `FlowReverted`). Accounts narrow to **savings movements only**.
- **ADR-0017** — **`RecurringPayment`**: recurrence-rule discriminated hierarchy + two schedule modes (**Live** rule / **Materialized** list); InstallmentPlan collapsed in; occurrences tracked via back-refs on AccountingPeriod (no per-occurrence state on the aggregate).

### Landed 2026-06-27 (Money ADRs 0018–0023) — the period-centric shift
- **ADR-0018** — Planned purchases on AccountingPeriod (period-centric planning); **PurchaseOrder dropped for v1**; Asset ingestion amended (paid entry → Asset, no PO).
- **ADR-0019** — **Universal line-items**: `FlowRecorded` / `PlannedPurchaseAdded` / recurring estimates all carry `list<Line>` (per-line `Category`; entry-level tags removed).
- **ADR-0020** — Recurring **Live carry-make-up** defer (skip + a disconnected one-off next period, for arrears like back-rent).
- **ADR-0021** — Close flow: surplus/deficit **split across multiple savings accounts** (user-truth, **not validated** against projected); unpaid-item dispositions (cancel/defer/skip/re-date/carry-make-up) appended in the close transaction; atomicity tentative pending implementation.
- **ADR-0022** — Wishlist items + packages (non-event-sourced documents) + derived **`WishlistItemStatus`** projection (`NotPlanned`/`Planned`/`Ordered`/`Received`); fine-grained items grouped by package.
- **ADR-0023** — Active-month model: **multiple periods may be open**; **future periods accept planning operations only** (no actuals/close); actuals route by date; active period = UI focus; no "open next" ceremony.

This session **resolved flow-list items 1 (close/reconciliation), 2 (planning levers), and 3 (Wishlist/PO)**, plus the **active-month/period model** and the **PO↔installment overlap** (installments = Materialized RecurringPayment; planned purchases = period events; PO dropped).

### Landed 2026-06-28 (Money ADRs 0024–0027) — categories, budgets, actuals honesty, early payment
- **ADR-0024 — Category model (managed):** the dual-track tag model is **superseded**. Categories are now a managed list — **system** (Books, Board Games, Video Games; code constants, immutable) + **user** (full CRUD, soft-archive). A line carries one **`CategoryId`** plus a separate direct **`ExternalRef`** (specific domain object; auto-categorizes when it matches a system category). No tags.
- **ADR-0025 — Budget (period-centric, category-targeted):** Budget becomes a **Marten document** (supersedes 0006's aggregate) targeting a `CategoryId`; a `BudgetActuals` projection groups `FlowRecorded` lines by per-line `CategoryId` (signed sum, event-time FX). Per-period + client "copy last month" bulk; no templates.
- **ADR-0026 — Actuals honesty & savings movements:** the `ActualSavingsOverride` god-number is **removed** — the honesty valve is now an **`UnaccountedFlowRecorded`** gap entry, so **actual = Σ flows** always and the ledger stays complete. Close distributes Σ flows across accounts (resolves 0021's override-vs-allocations by elimination). **Dipping into savings = close-time aggregate** (no mid-month per-purchase withdrawals in v1). Names the **`SavingsMovementRecorded`** event (replaces the generic `TransactionRecorded` on Account). Variance = actual − projected (computed).
- **ADR-0027 — Early payment (2-event model):** paying a future-period occurrence early writes the `FlowRecorded` in the **paying period** + an **`OccurrencePaidInAdvance`** status marker on the **occurrence's period** (atomic). Marker is display-only (the actuals fold ignores it); period-local reads; **stream-enforced idempotency** (Marten concurrency on the occurrence's period). Amends 0016/0017/0023.

This session **resolved flow-list item 4 (Budgets)** and the two big deferred topics — **actuals/override/dipping** and **early payment** — plus re-modeled categorization from dual-track tags to a managed category list.

### Confirmed, not yet written up
- **Home functional spec** — two sections: active-month **plan canvas** + **savings-accounts glance**; recurring items as a confirm **checklist** with progressive realization. Now largely implied by the period-centric model (ADR-0018/0019); write up when Home is built.
- **Offline-first** — drafted (Proposed) in [Wallet ADR-0004](./docs/adr/0004-offline-first-sync.md) (`0001` was already taken by localization). The base decision lived informally in AGENTS.md (read models + outbox + idempotency); ADR-0004 freezes it plus the choices the period-flows cache slice (2026-06-30) forced, and is **pending acceptance**:
  - **Operations log, not just a drain queue (idea — not built).** Evolve `pending_operations` from a transient queue (synced rows retired and forgotten) into a **durable log of *all* operations, complete and pending**, with **only pending shown by default**. Benefits: an audit/history of every change, a real answer to "what did I do while offline?", and a natural fit with the uniform-queue path below. Today's behavior still retires synced rows; captured here so the eventual schema (retain + status filter, retention/pruning policy) and a possible "activity/history" surface account for it from the start.
  - **Uniform outbox path vs "POST immediately when online."** AGENTS currently says: online → POST directly and update the cache from the response. The implementation instead **always queues** (one path on- and offline) and refreshes the cache via a background revalidation GET. Lean: keep the uniform-queue path (it pairs with the operations log). The ADR should settle this.
  - **Drain → cache coupling (the sync-flicker tradeoff).** A generic, feature-agnostic drainer leaves a sub-second flicker (a synced op leaves the optimistic overlay before the revalidate lands the confirmed row). A response-aware drain that writes the confirmed row removes the flicker but couples the drainer to the feature. The ADR should pick a stance.
  - **Cache retention** — period flows are keep-everything, no eviction (deliberate; tiny rows, immutable past periods). Revisit for multi-year accounts.
  - **Connectivity-driven auto-drain** (`connectivity_plus`) — still deferred; replay currently fires on launch / sign-in / after-enqueue, not on reconnect.

### Still to discuss (flow list)
5. **Accounts management** — create/edit (rename/archive) and **transfers** (paired `SavingsMovementRecorded` entries sharing a `TransferId`, deferred per ADR-0009). Savings movements themselves are defined (`SavingsMovementRecorded`, ADR-0026); account CRUD is trivial and also deferred. Low priority — the real v1 work (categories, budgets, actuals, early payment) has landed.

### Deferred sub-decisions (not blocking; captured in Money ADR README)
- **Skip-periods** (catch-up UX); **Asset shape** (Phase 3); **Projection strategy** (forcing function: MonthProjection); `nth weekday of month` recurrence subtype; **Transfers** (paired, ADR-0009); **`ExternalReference` snapshot caching** (Phase 2).
- **Mid-month per-purchase "fund from savings"** — dipping into savings is **close-time aggregate only** in v1 (ADR-0026); an opt-in real-time advance (netted at close) is a deferred enhancement.

> Note: "MonthlyReview" is superseded by **AccountingPeriod** (ADR-0016); planned purchases are period events (ADR-0018); spending entries are line-itemed (ADR-0019); WishlistItem is a document + projection (ADR-0022); the PurchaseOrder aggregate is dropped for v1 (ADR-0018); categorization is a managed **`CategoryId`** (ADR-0024, tags removed); the `ActualSavingsOverride` is removed (**actual = Σ flows**, ADR-0026); Budget is a document targeting a `CategoryId` (ADR-0025); early payment uses a 2-event model (ADR-0027).

---

## 13. Navigation & information architecture

> **Status:** **Decided** in the functional-design pass (2026-06-29). Frozen in **[Wallet ADR-0002](./docs/adr/0002-navigation-and-information-architecture.md)** (nav + Home cockpit) and **[Wallet ADR-0003](./docs/adr/0003-category-colour-system.md)** (category colours). This section is the at-a-glance summary; the ADRs are authoritative.
>
> **Designs:** visual mockups + screenshots of the Home cockpit, row spec, and category palette live in **[`docs/design/home/`](./docs/design/home/)** (illustrative references, not app code — the ADRs win where they disagree).

The app has **two conceptual axes**:
- **Cash-flow** — money moving through a month (Home + Activity), with Accounts as the cash you hold.
- **Possessions** — the lifecycle of *things*: `Wishlist → Planned purchase → Owned (Asset) → Resale value`. Net worth is the roll-up across both axes (`accounts + asset values − outstanding installments`, §6).

Not everything is a page. Surface types: **Page** (nav destination) · **Section** (region of a page) · **Sheet/Wizard** (modal, launched contextually) · **Inline** (tap-to-edit) · **Panel** (lightweight overlay/curtain).

### The shell — four destinations, adaptive chrome

> **Home · Activity · Accounts · Wishlist**

Adaptive: bottom `NavigationBar` (phone-portrait `<720`) → `NavigationRail` (`720–1240`) → extended labelled sidebar (desktop/web-landscape `≥1240`). **Settings** is a full-screen route *above* the shell (app-bar gear), not a nav slot.

| Page | Holds |
|---|---|
| **Home** | The **current-period cockpit** (not a stats readout): period switcher (multiple open periods, ADR-0023); reactive **on-track strip** (projected vs. target, ADR-0007) with a `details ▾` expand into **per-category budget bars** (ADR-0025); the **worklist**; add-flow FAB; entry to **Close** (ADR-0021/0026). |
| **Activity** | The flows log (line-itemed actuals) across periods; add/edit/revert; filter/group by category. |
| **Accounts** | Savings/cash accounts + balances; create/rename/archive; balance override; transfers (deferred, ADR-0009). Pinned **Rates** card in the desktop side rail. |
| **Wishlist** | The browseable backlog (items + packages, ADR-0022); "plan into this month" feeds Home. **Grows a second lens — Inventory / Net worth — in Phase 3** as the Asset aggregate (ADR-0010) ships. |

### Home worklist — grouping & rows

- **Default grouping: by realized status** — **Upcoming** (not-yet-a-flow: recurring occurrences *and* planned purchases, intermixed; the row icon carries the verb) vs. **Logged** (`Σ flows`). Mirrors projected-vs-actual (ADR-0007/0026). A **by-type toggle** offers **Recurring / Planned / Ad-hoc**.
- *Rejected groupings:* "must-pay vs. maybe" (no such field — never invent one) and by-category (entries are containers; category is per-line, ADR-0019 — category is a lens in the budgets expand / Activity).
- **Rows are containers:** `icon · name · [proportion bar + count] · amount`. Multi-line → chevron + split bar + "N items", expands to per-line rows. Multi-line/one-category → solid bar + "N items · Category", still expandable. Single-line → solid bar + category name, **no chevron**. Bar/dot colours per ADR-0003.

### Plan dissolved

There is no "Plan" page. Its contents redistribute: **recurring rules** edited in-context from their Home row; **budget targets** in Home's budgets expand / Settings; **wishlist** is its own destination. (Resolves the former "Plan: merged vs. split" thread by deletion.)

### Secondary (not a nav slot)

| Page | Holds |
|---|---|
| **Settings** | Locale (ADR-0001), theme, app-lock & passkey (ADR-0014), display currency & month-start (ADR-0013), **Categories** management incl. **colour** (ADR-0024 + Wallet ADR-0003), rates pinning (ADR-0015). |

### Non-page surfaces

| Surface | Type | Where |
|---|---|---|
| **Rates** (ADR-0015) | Panel/curtain + pinned card | Curtain pulled up where conversions appear; a pinned-rates card in the desktop Accounts/side rail. Behind the curtain on phone. Not a page. |
| **Close month** (ADR-0021/0026) | Wizard | Launched from Home when the period is ready to close. |
| **Add flow** | Quick-add sheet | Global (FAB), lands in Activity / Home's Logged. |

### Category colours (ADR-0003)

A curated **12-colour Calm palette** (Sage · Teal · Denim · Indigo · Plum · Rose · Rust · Clay · Ochre · Olive · Stone · Slate), light + dark renderings, assigned per category in Settings → Categories. System category *names* stay locked (ADR-0024) but colour is recolourable. Colour is a **client/display** concern (device-local override; deterministic default from `CategoryId`), never on Money's `Category`.

---

*Last updated: 2026-06-29*
