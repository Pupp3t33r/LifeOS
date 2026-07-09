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
3. **Honesty valves everywhere.** Target savings, the actual-savings gap entry (`UnaccountedFlowRecorded`, ADR-0026), savings account balance override, asset estimated value — user-truth beats computed-truth wherever a real number matters.
4. **No false precision.** Don't display a balance the user can't verify. Don't imply the app knows what it doesn't. The actual-savings gap entry is the explicit acknowledgment of this.
5. **Solo-first, family-aware.** v1 is single-user. The data model carries `OwnerId` everywhere so adding family UX later is a UI concern, not a migration.

---

## 4. Phase 1 — Solo planner (v1 scope)

### Platforms

Android, Web, Windows, Linux. (macOS/iOS technically free; not prioritized.)

### Screens

> *The "Backend (Money)" column below reflects the **current** aggregate map (the 2026-06/07 ADR waves). Earlier drafts named now-dead shapes — `MonthlyReview`, `InstallmentPlan`, `PurchaseOrder`, `TransactionRecorded`, `Budget (ADR-0006)` — all superseded; see §12 for the trail.*

| Screen | Job | Backend (Money) |
|---|---|---|
| **Month overview (Home)** | Savings canvas: target / projected / actual; planned-purchase summary; recent activity preview | `AccountingPeriod` + `MonthProjection` (ADR-0016, ADR-0007) |
| **Recurring editor** | Engine of projections: known income, bills, subscriptions, payment plans (installments collapsed in) | `RecurringPayment` — Live / Materialized (ADR-0017) |
| **Wishlist + planned purchases** | What you want vs. what fits this month; plan-into-month action (no PO) | `WishlistItem` + period `PlannedPurchase*` (ADR-0022, ADR-0018) |
| **Activity (flows) log** | Optional actuals — line-itemed flows that refine projections | `FlowRecorded` on `AccountingPeriod` (ADR-0016, ADR-0019) |
| **Light budgets** | Per-category spend targets; actuals plugged in when logged | `Budget` document + `BudgetActuals` (ADR-0025) |
| **Savings accounts** | List of accounts with balances (override-enabled); create/edit | `Account` + `SavingsMovementRecorded` (ADR-0009, ADR-0026) |

### Out-of-scope for v1

- Domain-linked purchases — the want→order→own flow (Phase 2: Books, Board Games; Money ADR-0030/0031/0032)
- Net worth & a Stats destination (Phase 3: Asset lifecycle + projections)
- Family UX (Phase 4)
- Long-term analytics, year review, reports (Phase 5)
- Voice/photo receipt capture (depends on Document Processing service)
- Bank/SMS auto-import (out of scope indefinitely unless a forcing function arrives)
- Savings goals (named allocation pools) — Wishlist already serves this purpose

### Backend prerequisite

v1 requires the full Phase 1 Money backend (see [Money PLAN.md](../../services/money/PLAN.md) §3). Sequencing is **backend-first**: Money features land, then Wallet UI is built against the real API. No mock/stub parallel track in v1.

### Auth & first-run (Money [ADR-0014](../../services/money/docs/adr/0014-auth-session-lifetimes-and-passkeys.md))

- **First-run onboarding** *(built)* — "Set up your first month": first savings account + display currency + configurable month start day (Money ADR-0013). The router gates on `UserPreferences.DisplayCurrency` being null; a single centred, width-capped question column that scrolls on short viewports. (The earlier two-column "savings canvas" preview was dropped — its figures were all pre-setup placeholders, misleading at that stage.)
- **Per-platform session scope** *(built)* — requests `offline_access` on native/desktop only, omits on web (`AuthConfig.scopes` gated on `kIsWeb`). Native gets a long offline session (idle 60d / max 180d); web a short online session (idle 30m / max 24h). One realm config, split by scope.
- **Biometric app-lock** *(built, native only)* — via `local_auth`: required on cold start, re-lock after ~5 min in background, user-configurable (default on); optional toggle shown in onboarding only where the device supports it. The lock screen always offers **"Use password"** and **"Log out / sign in as a different account."** No-op on web. On-device biometric prompt pending manual verification.
- **Passkey login** *(built, web-verified)* — WebAuthn/FIDO2 as the preferred Keycloak login method, **password always available as fallback** (bootstrap + recovery). On Keycloak 26.4+ enabling `webAuthnPolicyPasswordlessPasskeysEnabled` auto-integrates passkeys (conditional + modal UI) into the default browser flow — no custom flow JSON needed. The custom login theme's `template.ftl` must include the `rfc4648` import map the base theme provides, or the WebAuthn ES modules fail silently ("Failed to resolve module specifier rfc4648") and `navigator.credentials.create/get` never runs. Verified end-to-end via a Chrome virtual authenticator: enrollment (alice is seeded with the `webauthn-register-passwordless` required action → registers a passkey, password fallback retained) and passkey-only login (conditional-UI autofill → auth code, no password).

#### Auth — remaining / revisit later

Auth is **dev-complete and verified** as of 2026-06-26. None of the below are blockers; they are on-device checks that need real hardware, one optional UX, and deployment-phase hardening. Pick up here when able.

- [ ] **On-device biometric app-lock prompt** *(manual verify)* — the `local_auth` flow is proven as a web no-op; the real fingerprint/face prompt on a native device is untested.
- [ ] **Native / platform passkey authenticator** *(manual verify)* — passkey enrollment + passwordless login verified on web with a virtual authenticator; a real device/platform authenticator is untested.
- [ ] **In-app passkey enrollment deep-link** *(optional UX)* — the enrollment *mechanism* works (Keycloak `webauthn-register-passwordless` required action / Account Console); surface it from Wallet settings as the in-app opt-in ("A+B").
- [ ] **Prod hardening** *(deployment phase)* — real WebAuthn RP ID (passkeys currently assume `localhost`); Postgres-backed Keycloak DB (dev uses an H2 data volume); real secrets (not `devsecret` / `admin`/`admin`); brute-force protection (currently `bruteForceProtected: false` in the dev realm).
  - ⚠️ **Do NOT carry the dev realm's seed users to prod.** `aspire/LifeOS.AppHost/keycloak/lifeos-realm.json` is a **dev-only** realm: it ships known-password test users (`devuser`, `alice`, `bob`, and `contract` — the last one exists solely so the ROPC-based `KeycloakContractTests` work, since `alice` carries a passkey required action that blocks direct-grant). Prod is a separate, IaC-managed Keycloak (per AppHost.cs) that must **not** import this file. When wiring prod: provision real users only, drop all seed users, and rotate every secret. Treat this dev realm as fixtures, never a prod seed.

---

## 5. Phase 2 — Domain-linked purchases (the want→order→own flow)

When Books and Board Games services come online, Wallet gains the full **want → order → own** flow for domain-linked goods (board games first, via BGG; then books; `ServiceType`-agnostic). This is a **real flow**, not merely "richer" existing UI. Settled backend (Money ADR-0030/0031/0032, all Accepted 2026-07-08):

- **External linking (ADR-0030)** — one `ExternalReference {ServiceType, ExternalId}` with two homes: `WishlistItem.ExternalRef` (desire) and `Line.ExternalRef` (transaction). Cross-service via **Kafka events** — Money publishes/consumes, **never calls out**; the client does the provider (BGG) lookup; `ExternalId` is minted by the domain app on save or pre-assigned by Wallet only to skip the round-trip. Categories auto-populate from domains (`books`, `board-games`). This is the **first cross-domain event** → forces the deferred Kafka envelope/outbox decisions.
- **The Order aggregate (ADR-0031)** — event-sourced procurement on its own **cross-period** stream; typed ancillary costs (shipping/customs/handling) folded pro-rata into each asset's cost at receipt; fuzzy-or-precise ETA (month by default for intl post); a receipt confirmation window that pins per-item cost. Cancel reverts the wishlist; refund is separate.
- **Placement (Wallet ADR-0006)** — orders live on **Home** (a period-decoupled "Arriving" strip + a FAB "Buy" verb; cancel / edit / Mark-received from there); **Wishlist** gets its own tab.

Wallet may still deep-link to the relevant domain app (or show an inline preview via Gateway BFF composition). The Phase 1 data model already carries `ExternalReference`; the new build work is the **Order aggregate + its UI**, not a schema migration.

---

## 6. Phase 3 — Net worth & Stats

> *Framing set 2026-07-08 (Money ADR-0032, Wallet ADR-0006).*

- **Asset lifecycle (Money ADR-0032)** — the Asset is a **financial-only**, event-sourced record, **born at receipt** (no PurchaseOrder), states `Owned → Sold | WrittenOff`. Net worth = Owned only. A second ingestion path (`AssetImported`) backfills pre-existing possessions (`AcquiredDate`, `AcquiredCost`); its UI is **parked behind demand**.
- **The net-worth-effect boundary.** Possession states that move no money (loaned-to-a-friend, condition, played) are **not** Wallet's concern — they live in the owning **domain app** (Board Games, Books), **not** a Wallet "Inventory" screen. Wallet holds only value-moving events. (This kills ADR-0002's planned Wallet Inventory lens.)
- **Net worth → a future Stats destination** — a derived readout (savings balances + asset values − outstanding installment balances, display currency), something you *see*, not *operate*. **Deferred:** it depends on unbuilt projection/asset data, and the primary user is not net-worth-driven.
- **Bought-for vs sold-for stat** — computed on sold Assets, `SoldFor − AcquiredCost`, both FX-converted (ADR-0008).
- Gateway BFF may enrich Asset/collection rows with descriptive data (title, cover) from Books/Board Games for display; math never depends on enrichment.

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
| Inventory architecture | Asset = event-sourced **financial** record, born at receipt; possession states → domain apps (net-worth-effect boundary) | Money ADR-0032 (supersedes 0010) |
| External-domain linking | One `ExternalReference` (wishlist + line homes); cross-service via **Kafka**, Money never calls out; client does the provider lookup | Money ADR-0030 |
| Orders | Event-sourced Order aggregate on its own cross-period stream; typed ancillary costs folded into cost at receipt | Money ADR-0031 |
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

### Landed 2026-07-01 (Money ADR-0028) — payment-plan contents at the root
- **ADR-0028 — Contents at the aggregate root (amends 0017/0019):** the Materialized `RecurringPayment` (**Payment plan** in the UI) is restructured — line-item **contents move to a root `Items` list** (symmetric with Live's `EstimateLines`), a **`ScheduleLine` becomes bare money** (`{LineId, DueDate, Amount}`). A plan is authored once, immutable except cancel. Grouping / "what's in it" / order status reuse **ADR-0022** (Wishlist items + Packages) via `Line.WishlistItemId` — not the payment plan. UI design: [`docs/design/recurring/`](./docs/design/recurring/) — FAB is **Add · Ongoing · Payment plan**; the word "recurring" is dropped from the UI. *(Its priced-items / balance / proportional-slice parts are superseded by ADR-0029 below.)*

### Landed 2026-07-07 (Money ADR-0029) — priceless plan items — **built (backend + Flutter)**
- **ADR-0029 — Priceless plan contents (supersedes ADR-0028 §3–§4):** an all-in payment plan is *discounted and never itemised by real per-item cost*, so hand-entering per-item prices that must sum to the payments was tedious and fictional. A Materialized item becomes a **priceless `PlanItem`** (`{description, referenceValue?, categoryId?, wishlistItemId?}`) — `referenceValue` an optional informational MSRP, never summed; **no balance invariant** (plan total = **Σ payments**); **confirm records a plain reference** — one line at the amount actually paid (default scheduled, **adjustable**) under the plan's category + back-ref, **no itemisation / no slice**. Per-item cost is deferred to a **Phase-3 net-worth valuation** (MSRP-weighted split of the actual total). Flutter: the **Payment plan** create sheet takes priceless items (name + optional MSRP + category) with a live **Σ-payments plan total** (no "must balance" UI), and the **plan resolve sheet** shows an editable "what was actually paid" amount + "what's in the plan" contents. Money 143 tests green; wallet analyze green. Event break → reset the local `money-db` volume.

### Landed 2026-07-07 (Money ADR-0018) — planned single purchases — **built (backend + Flutter)**
- **ADR-0018 — Planned purchases on the period, now implemented:** a **planned single purchase** ("I intend to buy X this month") is neither a payment plan nor a new aggregate — it is three events on **`AccountingPeriod`** (`PlannedPurchaseAdded` / `PlannedPurchaseEdited` / `PlannedPurchaseCancelled`), always spending, line-itemed (ADR-0019). **Paying it = a `FlowRecorded` carrying a `PlannedEntryId` back-ref** (mirrors occurrence confirm, ADR-0017): `FlowRecorded` gained the optional `PlannedEntryId`, the aggregate guards live/cancelled/paid id-sets, and status (planned/paid) is a read-time join — cancel deletes the read row. Endpoints: `POST/GET/PUT/DELETE /months/{y}/{m}/planned-purchases[/{id}]` + `POST …/{id}/pay` (pay amount adjustable, defaults to the plan). 13 endpoint tests green; whole Money suite green.
  - **Flutter:** FAB gains a 4th verb **Planned purchase** (gated to active/future periods, files onto the *viewed* period); a single-line create sheet; Home **Upcoming** now intermixes planned purchases with recurring occurrences via a unified `UpcomingItem` union; planned tiles get a **Buy** (pay, adjustable) on the active period and a remove action, all outbox-backed (`add`/`edit`/`cancel`/`pay_planned_purchase`) with optimistic drop from Upcoming. Wallet analyze green.
  - **Scoped out for now (follow-ups):** **pay is same-period only** (the flow files onto the planned purchase's own period; cross-period settlement is the ADR-0027-style late/early case, deferred); **edit UI** is not surfaced (the endpoint + outbox op exist); **defer-at-close** belongs to the Close flow (ADR-0021, not built); create sheet is **single-line** (the model stays multi-line-capable).
  - **Schema note:** additive only — new event types + an optional `PlannedEntryId` on `FlowRecorded` (old events deserialize to null) + a new inline `PlannedPurchaseRecord` projection. No `money-db` volume reset required.

### Landed 2026-07-08 (Money ADR-0030/0031/0032 + Wallet ADR-0005/0006) — the want→order→own flow & nav revision — **design (ADRs), not built**
- **Wallet ADR-0005 — the Plan destination** (reverses §13's "Plan dissolved"): Plan is **reinstated** as a three-view tab — **List** (definitions library) · **Board** (try-on scheduling of wishlist wants across months) · **Budget** (spending limits + savings target). Backlog *management* + final nav slotting left open. Mockups in [`docs/design/plan/`](./docs/design/plan/).
- **Money ADR-0030 — external-domain linking** (the Phase 2 contract): one `ExternalReference` with two homes (`WishlistItem.ExternalRef` desire, `Line.ExternalRef` transaction); cross-service via **Kafka events** — Money publishes/consumes, **never calls out**; the client does the provider (BGG) lookup; `ExternalId` minted by the domain app on save or pre-assigned by Wallet only to skip the round-trip; `Estimate` optional. **First cross-domain event** → forces the deferred Kafka envelope/outbox decisions.
- **Money ADR-0031 — the Order aggregate:** event-sourced procurement on its own **cross-period** stream; typed **ancillary costs** (shipping/customs/handling) allocated into each asset's cost at receipt; **fuzzy-or-precise ETA** (month by default for intl post); receipt confirmation window; cancel reverts the wishlist, refund separate. Supersedes ADR-0018's direct fulfillment path + ADR-0019's lone shipping tag.
- **Money ADR-0032 — the Asset lifecycle:** event-sourced **financial** record, **born at receipt**, `Owned → Sold | WrittenOff`; net worth = Owned. **Net-worth-effect boundary:** possession states (loaned-to-a-friend, condition) move no money → they live in the owning **domain app**, not Wallet. Resolves the deferred Asset-shape decision (supersedes ADR-0010's shape/lifecycle). Generic non-domain assets (TV/fridge) + the `AssetImported` backfill UI deferred behind demand.
- **Wallet ADR-0006 — acquisition placement + nav revision** (amends ADR-0002): **orders live on Home** (a period-decoupled "Arriving" rolling-30-day strip + a FAB "Buy" verb; cancel/receive from there); **Accounts folds into Home** (a pots glance + a "Manage" surface — account mgmt is low-frequency); owned **collection → domain apps**; owned **value/net worth → a future Stats destination**. Home's thesis widens to **"current standing"** (this month's flow + period-independent stocks). Revised near-term shell **Home · Plan · Wishlist · Activity**. Wishlist-tab + Stats **provisional**, pending the app-wide feature-map review.

### Landed 2026-07-08 (Wallet ADR-0007) — Calm typeface — **design (ADR), not built**
- **ADR-0007 — Manrope (single variable super-family):** replaces Calm's **Bricolage Grotesque (display) + Spline Sans (body)** with one **Manrope** family (200–800, Latin + **Cyrillic**), closing the Spline-Sans Cyrillic gap that left shipped Russian body text (ADR-0001) in a platform-fallback font. Edited in the shared design tokens (`tokens.json` → `tokens.css` + `calm_tokens.dart`), so Keycloak login + Wallet app swap together. **No Calm font is bundled today** — this also first ships the Manrope variable asset; bundling specifics + mockup/theme refresh deferred to implementation.

### Confirmed, not yet written up
- **Home functional spec** — two sections: active-month **plan canvas** + **savings-accounts glance**; recurring items as a confirm **checklist** with progressive realization. Now largely implied by the period-centric model (ADR-0018/0019); write up when Home is built.
- **Offline-first** — **frozen in [Wallet ADR-0004](./docs/adr/0004-offline-first-sync.md)** (2026-06-30; `0001` was already localization). Settles what had lived informally in AGENTS.md plus the calls the period-flows cache slice forced: cached read models + a write outbox + idempotent replay (Money ADR-0003); **writes always queue** (one uniform path, no "POST directly when online"); **stale-while-revalidate** reads; **pending shown & counted in the view via an outbox overlay but never written to the cache** (cache = server truth), with the in-flight portion surfaced by a self-erasing "includes −$X syncing" caption ("Option A"); `failed` (server-rejected) ops excluded from every figure; **keep-everything** cache retention. Deferred follow-ups (future ADRs/work), all captured in ADR-0004:
  - **Operations log, not just a drain queue (idea — not built).** Evolve `pending_operations` from a drain-and-forget queue (synced rows retired) into a **durable log of *all* operations — `synced`/`pending`/`failed` — showing only pending by default**: an audit/history of every change, the home for the `failed`/resolve-me surface, and a natural fit with the uniform-queue path. Needs a schema change (retain + status filter + retention/pruning) and a possible activity/history surface.
  - **Response-aware drain (kill the sync-flicker).** A generic drainer leaves a sub-second flicker; writing the confirmed row from the mutation's response removes it but couples the drainer to the feature. Deferred.
  - **Connectivity-driven auto-drain** (`connectivity_plus`) — replay currently fires on launch / sign-in / after-enqueue, not on reconnect. Deferred.
  - **Outbox error-handling / failed-op resolution (design not started — deferred).** ADR-0004 defines the `failed` state (server-rejected 4xx, excluded from every figure, "surfaced as something to resolve") but the actual **resolution design does not exist yet**: no user-facing surface for failed ops, no retry / edit-and-resend / discard flow, and no per-entity **error taxonomy** (which 4xx from which endpoint means what, and what the user can do about each). Today a `failed` op is simply dropped from figures and left as a silent diagnostic row. **Blocked by scope, deliberately:** this is one conversation best had once the *full set of syncable entities* is known and each one's error types are catalogued — currently `record_flow`, and (incoming with this feature) `create_recurring` / `confirm_occurrence` / `skip_occurrence` / `cancel_recurring`, each with its own rejection modes (e.g. balance-invariant 400, plan-override 400, unknown-occurrence 404, double-resolve 409-as-synced). Its eventual home is the operations-log surface above. **Do not design piecemeal per feature** — capture each new op's error modes as they land, and hold the resolution UX until the catalogue is complete.
  - **Offline occurrence projection for recurring (deferred *indefinitely*).** Recurring creation is **outbox-backed** (in scope): the write is durable and syncs, and once the `create_recurring` op drains the new item's occurrences appear in the worklist. But *until* it drains they don't, because occurrence expansion is a **server-side projection** (Money `GetOccurrencesEndpoint`: the rule generator for Live; the schedule + **proportional slice** for Materialized; joined against the period's paid/skipped back-refs). Rendering a just-created recurring's occurrences *immediately while offline* (before sync) would mean **porting that projection to Dart**. Deferred indefinitely: it duplicates Money's domain logic on the client (rule generator + `ProportionalAllocation` + the status join) and must stay in lockstep forever — a scoped cousin of **ADR-0004 Alternative #4** (client-side projection / full local replica), which was *rejected hard*.
    - **The only scenario that would justify it:** fully offline, the user creates a **Payment plan** *and immediately marks its first payment paid*, with no server round-trip in between. Without a local projection there's no occurrence row to tap, so this exact flow is impossible offline. That's the whole motivation — weigh it only if this offline sequence becomes a real requirement.
    - **Ordering it would require (already satisfied):** the `create_recurring` op must drain **before** the dependent `confirm_occurrence` op, or the confirm 404s. The current single, app-lifetime, **oldest-first** drainer already guarantees this — the create is enqueued first, so it has the earlier `createdAt` and replays first. The one latent gap is same-instant enqueues **tying** on `createdAt` (drift stores it as unix seconds; no tiebreaker today). A monotonic `seq`/rowid tiebreak closes it — **deferred until this projection is actually on the table** (not worth it for the current sync-after-write behaviour, where nothing depends on intra-second order).
    - **If ever taken on:** add a Dart occurrence projector (Live rule expansion + Materialized slice + a projected/paid/skipped overlay decoded from the outbox), a pending-occurrences provider that feeds the worklist, and the drain tiebreaker above — scoped to the recurring feature only, never a general local replica.

### Still to discuss (flow list)
5. **Accounts management** — create/edit (rename/archive) and **transfers** (paired `SavingsMovementRecorded` entries sharing a `TransferId`, deferred per ADR-0009). Savings movements themselves are defined (`SavingsMovementRecorded`, ADR-0026); account CRUD is trivial and also deferred. Low priority — the real v1 work (categories, budgets, actuals, early payment) has landed. *(Placement decided 2026-07-08, Wallet ADR-0006 — folds into **Home** behind a "Manage" affordance, **not** a nav tab; build still deferred.)*

### Deferred sub-decisions (not blocking; captured in Money ADR README)
- **Skip-periods** (catch-up UX); **Asset shape** (Phase 3); **Projection strategy** (forcing function: MonthProjection); `nth weekday of month` recurrence subtype; **Transfers** (paired, ADR-0009); **`ExternalReference` snapshot caching** (Phase 2).
- **Mid-month per-purchase "fund from savings"** — dipping into savings is **close-time aggregate only** in v1 (ADR-0026); an opt-in real-time advance (netted at close) is a deferred enhancement.

> Note: "MonthlyReview" is superseded by **AccountingPeriod** (ADR-0016); planned purchases are period events (ADR-0018); spending entries are line-itemed (ADR-0019); WishlistItem is a document + projection (ADR-0022); the PurchaseOrder aggregate is dropped for v1 (ADR-0018); categorization is a managed **`CategoryId`** (ADR-0024, tags removed); the `ActualSavingsOverride` is removed (**actual = Σ flows**, ADR-0026); Budget is a document targeting a `CategoryId` (ADR-0025); early payment uses a 2-event model (ADR-0027).

---

## 13. Navigation & information architecture

> **Status:** the near-term shell is **[Wallet ADR-0002](./docs/adr/0002-navigation-and-information-architecture.md)** (Home cockpit + IA) as revised by **[ADR-0005](./docs/adr/0005-plan-destination-and-planning-views.md)** (Plan reinstated) and **[ADR-0006](./docs/adr/0006-acquisition-flow-placement-and-nav-shell-revision.md)** (shell revision — Accounts folds into Home). Category colours: **[ADR-0003](./docs/adr/0003-category-colour-system.md)**. This section summarizes; the ADRs are authoritative. **Wishlist-as-a-tab and a future Stats destination are provisional**, pending an app-wide feature-map / IA review that owns the final nav.
>
> **Designs:** visual mockups of the Home cockpit, row spec, and category palette live in **[`docs/design/home/`](./docs/design/home/)**; the Plan views in **[`docs/design/plan/`](./docs/design/plan/)** (illustrative references, not app code — the ADRs win where they disagree).

The app has **two conceptual axes**:
- **Cash-flow** — money moving through a month (Home + Activity), with the savings pots as the cash you hold (folded into Home, ADR-0006).
- **Possessions** — the lifecycle of *things*: `Wishlist → Order → Owned (Asset) → Resale value`. Owned collection lives in the **domain apps** (net-worth-effect boundary); net worth is the roll-up (`accounts + asset values − outstanding installments`, §6) on a future **Stats** destination.

Not everything is a page. Surface types: **Page** (nav destination) · **Section** (region of a page) · **Sheet/Wizard** (modal, launched contextually) · **Inline** (tap-to-edit) · **Panel** (lightweight overlay/curtain).

### The shell — four destinations, adaptive chrome

> **Home · Plan · Wishlist · Activity**

Accounts is **not** a tab — it folds into Home (a pots glance + a "Manage" pushed surface, ADR-0006). **Stats** arrives later, when net worth + projections are real. Adaptive: bottom `NavigationBar` (phone-portrait `<720`) → `NavigationRail` (`720–1240`) → extended labelled sidebar (desktop/web-landscape `≥1240`). **Settings** is a full-screen route *above* the shell (app-bar gear), not a nav slot.

| Page | Holds |
|---|---|
| **Home** | The **current-standing cockpit** — this month's **flow** *plus* period-independent **stocks**. *Flow:* period switcher *(built)* — `‹ Month YYYY ›` chevrons + Active/Planning/Past status chip + snap-back-to-Current, multiple open periods (ADR-0023), browsed future period is planning-only; reactive **on-track strip** (projected vs. target, ADR-0007) with a `details ▾` expand into **per-category budget bars** (ADR-0025); the **worklist**; add-flow FAB (incl. **Buy / New order**); entry to **Close** (ADR-0021/0026). *Stocks:* a **savings-pots glance** → a "Manage" pushed surface (account list, create/rename/archive, deposit/withdraw, transfer, reconcile, history); an **"Arriving" orders strip** (rolling ~30-day window keyed on ETA — cancel / edit / Mark-received, ADR-0031). |
| **Plan** | Three views (ADR-0005): **List** (definitions library) · **Board** (try-on scheduling of wishlist wants across months) · **Budget** (per-category spend limits + savings target). |
| **Wishlist** | The browseable backlog (items + packages, ADR-0022); "order these wants" → an Order; "plan into this month" feeds Home. *(Provisional tab, pending the feature-map review.)* |
| **Activity** | The flows log (line-itemed actuals) across periods; add/edit/revert; filter/group by category. |

### Home worklist — grouping & rows

- **Default grouping: by realized status** — **Upcoming** (not-yet-a-flow: recurring occurrences *and* planned purchases, intermixed; the row icon carries the verb) vs. **Logged** (`Σ flows`). Mirrors projected-vs-actual (ADR-0007/0026). A **by-type toggle** offers **Recurring / Planned / Ad-hoc**.
- *Rejected groupings:* "must-pay vs. maybe" (no such field — never invent one) and by-category (entries are containers; category is per-line, ADR-0019 — category is a lens in the budgets expand / Activity).
- **Rows are containers:** `icon · name · [proportion bar + count] · amount`. Multi-line → chevron + split bar + "N items", expands to per-line rows. Multi-line/one-category → solid bar + "N items · Category", still expandable. Single-line → solid bar + category name, **no chevron**. Bar/dot colours per ADR-0003.

### Plan (reinstated)

Plan is a **destination** again — a three-view planning home (**List · Board · Budget**), frozen in **[ADR-0005](./docs/adr/0005-plan-destination-and-planning-views.md)**. *(History: the 2026-06-29 pass had dissolved Plan — recurring rules edited in-context from their Home row, budget targets in Home's budgets expand — but ADR-0005 reversed that. Backlog *management* + final nav slotting remain open, owned by the feature-map review.)*

### Secondary (not a nav slot)

| Page | Holds |
|---|---|
| **Settings** | Locale (ADR-0001), theme, app-lock & passkey (ADR-0014), display currency & month-start (ADR-0013), **Categories** management incl. **colour** (ADR-0024 + Wallet ADR-0003), rates pinning (ADR-0015). *(built: a searchable, grouped page — Appearance (theme System/Light/Dark + language), Money (display currency, month-start), Security (app-lock, native-only); passkey enrollment, Categories, and rates pinning still pending. Account name/opening balance are omitted — immutable server-side, no edit endpoint.)* |

### Non-page surfaces

| Surface | Type | Where |
|---|---|---|
| **Rates** (ADR-0015) | Panel/curtain + pinned card | Curtain pulled up where conversions appear; a pinned-rates card in the desktop side rail (Accounts is no longer a tab, ADR-0006). Behind the curtain on phone. Not a page. |
| **Close month** (ADR-0021/0026) | Wizard | Launched from Home when the period is ready to close. |
| **Add flow** | Quick-add sheet | Global (FAB), lands in Activity / Home's Logged. |

### Category colours (ADR-0003)

A curated **12-colour Calm palette** (Sage · Teal · Denim · Indigo · Plum · Rose · Rust · Clay · Ochre · Olive · Stone · Slate), light + dark renderings, assigned per category in Settings → Categories. System category *names* stay locked (ADR-0024) but colour is recolourable. Colour is a **client/display** concern (device-local override; deterministic default from `CategoryId`), never on Money's `Category`.

### Typeface (ADR-0007)

The Calm type roles (`font.display` / `font.body`) move from **Bricolage Grotesque + Spline Sans** to a single **Manrope** variable super-family (weights 200–800, full Latin + **Cyrillic**). Reason: shipped Russian *body* text (ADR-0001) fell back to the platform font because Spline Sans has no Cyrillic — a visible in-paragraph glyph mismatch. One family covers both roles (heavier for display, lighter for body), guaranteeing metric consistency across roles and scripts. The decision lives in the **shared Calm design tokens** (`design/themes/calm/tokens.json` → CSS + Dart bindings), so the Keycloak login and the Wallet app swap together. **Note:** no Calm font is bundled yet — this swap is also where the Manrope variable asset first ships; bundling specifics are deferred, and existing `docs/design/` mockups reference the old face until refreshed.

---

*Last updated: 2026-07-09*
