# ADR-0005: The Plan destination — a three-view planning home (List · Board · Budget)

## Status

Accepted

Date: 2026-07-08

**Amends** [Wallet ADR-0002](./0002-navigation-and-information-architecture.md): it **reinstates Plan** as a destination (ADR-0002 had dissolved it). It does **not** dissolve Wishlist. This ADR covers only how Plan **consumes and assigns** wishlist items — the Board tray surfaces *idle* items to drag onto months. The **wishlist backlog itself** — editing the list of items and associating them with external domain objects ([Money ADR-0022](../../../../services/money/docs/adr/0022-wishlist-items-packages-and-derived-status.md): packages, order status, and the Phase-3 possessions/net-worth axis) — is **undesigned and out of scope here**. Consequently the **final destination set, and where wishlist management lives, are left open** (see *Open threads*); the mockups draw a `Home · Plan · Activity · Accounts` rail **provisionally**. ADR-0002's Home cockpit, Upcoming/Logged worklist, container-row anatomy, and rejected groupings stand unchanged.

**Relates to:** [Wallet ADR-0003](./0003-category-colour-system.md) (row/limit colours), [Wallet ADR-0004](./0004-offline-first-sync.md) (the outbox write path this leans on). Money service: [ADR-0007](../../../../services/money/docs/adr/0007-monthly-review-and-projection.md) (`MonthProjection` — deliberately *not* depended on here), [ADR-0016](../../../../services/money/docs/adr/0016-accounting-period-flow-ledger.md)/[ADR-0017](../../../../services/money/docs/adr/0017-recurring-payment-rules-and-schedules.md)/[ADR-0018](../../../../services/money/docs/adr/0018-planned-purchases-on-accounting-period.md) (flows, recurring, planned purchases), [ADR-0022](../../../../services/money/docs/adr/0022-wishlist-items-packages-and-derived-status.md) (wishlist — unbuilt; a prerequisite), [ADR-0023](../../../../services/money/docs/adr/0023-active-month-model.md) (planning writes to future periods), [ADR-0025](../../../../services/money/docs/adr/0025-budget-period-centric-and-category-targeted.md) (budgets), [ADR-0028](../../../../services/money/docs/adr/0028-recurring-contents-at-root.md)/[ADR-0029](../../../../services/money/docs/adr/0029-recurring-materialized-priceless-contents.md) (plan contents & payments).

**Design mockups (frozen by this ADR):** [`apps/wallet/docs/design/plan/`](../../design/plan/) — `plan-list.html`, `plan-board.html`, `plan-budget.html`, `plan-detail.html` (drill-downs). `plan-options.html` is the retained A/B/C exploration history. Where a mockup and this ADR disagree, this ADR wins.

## Context

ADR-0002 dissolved the Plan page: the *instances* of its levers (recurring occurrences, planned purchases, budgets) surface on the Home cockpit, and their *definitions* were to be "edited in-context." Building against that surfaced two gaps ADR-0002 left open:

1. **No home for definitions.** Home deals in *instances* — this period's rows. Editing the *definition* behind one (an Ongoing's amount/rule, a payment plan, a planned buy) meant hunting for its instance on the right month. There was no period-agnostic place a definition lives. The app shell still carried a stubbed `/plan` route (`lib/features/money/ui/plan/plan_screen.dart`) with nothing in it.
2. **No forward view.** Home shows one period. *"What am I committed to over the next few months, and when does it bite?"* had no screen.

"Edited in-context" also spread definition-editing across the app with no way to see all recurring rules or plans at once — a negative ADR-0002 itself recorded. This ADR gives those definitions, and a forward view, one home. It also lets Plan **assign** wishlist items — drag idle wants onto months — but it does **not** take over the wishlist backlog's *management*, which stays a separate, still-undesigned concern (Money ADR-0022).

Backend reality (verified against `services/money`): per-recurring forward occurrences already exist (`GET /recurring/{id}/occurrences?from&to`); planned purchases and payment-plan `{date, amount}` lines are stored with dates. But there is **no** cross-period aggregate feed, **no** Wishlist entity (only a `Guid WishlistItemId` link on `PlanItem`), **no** budgets/savings-target persistence, and `MonthProjection` (ADR-0007) is Accepted-but-unbuilt. These shape what ships when.

## Decision

### 1. Reinstate Plan as a destination (nav slotting left open)

Plan returns as a planning destination. This ADR does **not** settle the full destination set: the wishlist backlog still needs a management home (undesigned — §9, *Open threads*), so whether Wishlist keeps its own slot, Plan takes the fourth slot with wishlist-management as a pushed sub-surface, or the rail carries five, is **deferred** — and deliberately so — to an upcoming **app-wide feature-map / IA review**, where every feature's home is decided together rather than piecemeal. The mockups use a provisional `Home · Plan · Activity · Accounts` rail. Adaptive chrome and Settings-as-a-route-above-the-shell are unchanged from ADR-0002.

### 2. Plan is one destination, three views

A single tab with a `List · Board · Budget` view toggle. Plan is **period-agnostic** — no period switcher; it is about definitions and the forward horizon, not one month. The boundary with Home is firm:

- **Home = instances.** This period's rows — log, confirm, buy, mark paid. Resolving stays on Home.
- **Plan = definitions + forward planning.** Create/edit the durable objects; plan wants across future months; set the month's shape.

### 3. List view (default) — the definitions library

Grouped, editable shelves: **Ongoing**, **Payment plans**, **Planned purchases**. Create lives here (`+ New` per shelf). Row footprints:

- **Payment plan rows** show **what's left** as the headline plus the **actual next payment** (`8 of 24 · next −$320 on Aug 3`) — **never a synthesized "per month,"** because payments are explicit `{date, amount}` rows of varying amount/cadence (ADR-0028/0029). The row action is **Manage** (not Edit).
- **Ongoing rows** show `↻ cadence · next date` and are fully editable.
- **Planned-purchase rows** are period-local; see §7 for the dated/dateless display.

### 4. Board view — the try-on timeline

The wishlist tray + a forward run of month columns.

- **Drag a want onto a month to plan it; the drop is the commit** — no dialog, no Save gate. Placements are period-local plans (ADR-0018) with no financial side effect and are reversible by dragging again; an **Undo** affordance covers slips. A staged/apply model is rejected — it fights the "least clicks" thesis and the offline-outbox write path (ADR-0004). Writing a plan onto a future period is already sanctioned by Money ADR-0023.
- **On phone the drag is real:** drag-start **collapses** every month to a header row (name + balance) and the wishlist to a single **cancel bar**, so every month in the window is a visible drop target; drop restores the resting view. No tap-a-want→tap-a-month picker.
- **The month window is derived, not paged.** The current year shows **this month → December**; any future year shows **all twelve**. The only control is the year selector; columns scroll horizontally when long.
- Each column shows the month's **committed weight** (Ongoing occurrences + plan installments) as a `fixed` base; dragged wants stack on top so you feel weight-on-top-of-fixed. The board needs *committed weight per month*, **not** the full `MonthProjection`.
- The tray filters by **category chips** + **title search**.
- The tray is an **assignment view of `idle` wishlist items only** — it reads and files them; it does **not** create/edit wishlist items or their external-domain associations. That management surface is out of scope (§9, *Open threads*).

### 5. Budget view — set the month's shape

- **Spending limit per category** (sliders) + a **savings target**.
- The tracked-category list is an **editable opt-in subset** of *existing* categories (add/remove; **no category creation** here — that is a later feature). A category not on the list is **not scored**; its spend pools into a single **Other** residual bucket with no limit.
- The **"Your month"** readout is **plain arithmetic on the levers** — `expected income − limits − target = free` — deliberately **not** `MonthProjection` (ADR-0007), so the view ships before that does.
- **No historical "typical spend" reference in v1.** It would drag in a by-category-over-time aggregate that doesn't exist and misleads on cold-start; add it later, history-gated and honestly labelled.
- These are **templates set here; Home does the live spent/limit tracking.**

### 6. Payment-plan lifecycle — Manage is its home

A payment plan is **immutable except `EditHeader` (name/category) and `Cancel` (refund / keep-paid)** (ADR-0028/0029). Tapping a plan opens **Manage**: read-only **priceless contents** + the full **`{date, amount}` schedule** (paid/next status), with the two write actions. Its **Edit** sheet is header-only, with contents and payments shown **locked**. To change terms: cancel and remake.

**A plan pays from the period, not an account.** Each installment comes out of the balance of the month it falls in — there is **no per-plan pay-from account**. Only an *extra / early* payment dips into a savings account, and that source is chosen **at pay-time**, not on the plan.

**Financed items do not appear on the Board.** A wishlist item financed by a plan is not a tray card — it shows only as the plan's installment weight (§4). The item lives in its plan; it is reached plan → contents, never item → month (items are priceless; only payments have money and a date).

### 7. Ongoing (Live) — full edit

Tapping an Ongoing opens a full Edit: expense/income, amount, name, category, and an editable **Repeats** rule (`ChangeRule`, ADR-0017), plus **Stop**. Changes apply to future occurrences; already-logged ones are untouched.

### 8. Planned purchase — a month, or a deadline that implies one

A planned buy files to **exactly one target month**. A single **switch** flips the input:

- **Off** → pick the **target month** directly (what a wishlist drag sets).
- **On** → pick a **deadline date**; the month is **derived** from it.

**Display:** no deadline → shown under the month, no date ("this month"); with deadline → a clay `by <date>` chip, sorted ahead of dateless buys, warning when near. Removing a wishlist-origin planned buy **returns the want to the wishlist**.

### 9. Wishlist model — the once/reusable flag is the keystone

A wishlist item carries a **one-time vs reusable** flag and a single **commitment state**: `idle` → `planned` (on a month) **or** `financed` (in a plan) **or** `bought`.

- **`once`** (fridge, tires): schedulable/buyable a single time. Dragging it out of the tray **removes** it (it's `planned`/`financed`); removing/cancelling **returns** it to `idle`; a move relocates the one instance (never duplicates).
- **`reusable`** (coffee, tea): **stays** in the tray; each drag spawns an independent planned purchase.
- The Board tray shows **`idle` wants** (+ all reusables). A `once` item that is `planned` or `financed` isn't in the tray — the Board and the plan-create flow are **symmetric doors** in/out of it. This is why the wishlist→payment-plan link is **kept, not dropped**: a financed item simply leaves the tray and shows as weight.

**Scope.** This ADR defines the `once`/`reusable` flag and the commitment state only as they govern **assignment** — what appears in the tray and what a drag does. **Managing the wishlist itself** — creating/editing/removing items, their prices and notes, and associating them with **external domain objects** (packages, order status, assets — Money ADR-0022) — is **not designed here** and needs its own surface (*Open threads*).

### 10. Drill-downs render per platform

Manage and every Edit sheet render as a **centered dialog on desktop** and a **bottom sheet on phone** — same content, framed to the platform. Cancel lives at the Manage level (Edit is reached from Manage, so it needs no second Cancel).

## Consequences

**Positive**

- Definitions get the home the model was asking for; all recurring rules / plans / planned buys are viewable and editable in one place, fixing ADR-0002's "definition-editing spread across the app" negative.
- The forward horizon ("when does it hurt") finally has a screen.
- Plan can assign wishlist items (drag-to-commit) without a separate step; the wishlist *backlog* stays a distinct surface, so nothing about item management is prejudged here.
- Budget ships without waiting on `MonthProjection`; the arithmetic readout is honest about being arithmetic.

**Backend prerequisites (to be recorded in Money ADRs as each is built)**

- A **cross-item, multi-period read** for the Board horizon (compose existing per-recurring `InWindow` + a range-widened planned-purchase query, bucketed by period). Medium; no new domain rules.
- The **Wishlist entity + `once`/`reusable` flag + commitment state** (Money ADR-0022, unbuilt) — the prerequisite for the Board tray. The `financed` state is computable today via `PlanItem.WishlistItemId`.
- The **wishlist link on the planned-purchase / flow `Line`** (Phase-2 today) — needed for the once-item leave/return round-trip.
- **Budgets + savings-target** persistence (nothing today).
- A **nullable `Deadline`** on the planned purchase — when set, derive the period from it; when null, the period is chosen directly.

**Build order** — **List** first (buildable on today's data). **Board** next: the read-only committed horizon is cheap; the full try-on is gated on the Wishlist entity. **Budget** last (largest net-new persistence). Ship the platform framing (dialog/sheet) with each.

**Negative / open threads**

- **The wishlist backlog management surface is undesigned, and it blocks the Board tray from being fully real** (the Board today consumes a wishlist that has no editing UI). It must cover: creating/editing/removing wishlist items; associating them with **external domain objects** (Money ADR-0022 packages & order status; the Phase-3 Inventory/Net-worth axis via the Asset aggregate, Money ADR-0010). Its home — and therefore the final **nav slotting** — is left to the upcoming **app-wide feature-map / IA review**, where all features' homes are decided together. Candidates on the table: Wishlist keeping its own destination, a pushed "Manage wishlist" surface reached from the Board tray, or a lens under Accounts.
- With the deadline switch **on**, editing the date can move the buy to a different month; a **"moved to <Month>"** confirmation is wanted when that relocation happens (especially off a Board column). Not yet designed.
- The **extra / early payment** flow (how much, which savings account) and the **Cancel-plan confirm** (refund vs keep-paid) are named but not yet drawn.

## Alternatives Considered

1. **Keep Wishlist as its own destination (5 slots, or Wishlist beside Plan).** **Not rejected — deferred.** This ADR only assigns wishlist items via the Board; it does not decide the backlog's home. Wishlist keeping a slot stays a live option against "wishlist-management as a pushed sub-surface of Plan," to be settled by the upcoming app-wide IA review — weighing phone bottom-bar capacity (ADR-0002 rejected five destinations) against discoverability of the backlog.
2. **Budget as a separate feature / defer it.** Rejected in favour of a third view — but kept honest by making its readout plain arithmetic so it doesn't block on `MonthProjection`.
3. **A Save gate on the Board** (staged changes + unsaved-changes guard + dirty-row highlight). Rejected: no financial side effect to guard, reversible objects, and it fights the drop-is-the-commit thesis and the outbox. Undo covers slips.
4. **Historical "typical spend" on budget rows.** Deferred: needs an unbuilt aggregate and misleads on cold-start.
5. **Showing a financed item on the Board / per-payment item lines.** Rejected: items are priceless (ADR-0029) and payments aren't attributable to one item; the honest unit on the timeline is the plan's payment weight.
6. **A required target-period field *plus* an optional deadline field.** Rejected for the single input-mode switch (§8), which makes a month/date contradiction unrepresentable.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
