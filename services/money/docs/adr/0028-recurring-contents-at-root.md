# ADR-0028: RecurringPayment — contents captured once at the aggregate root; Materialized payments carry money only (amends ADR-0017 and ADR-0019)

## Status

Accepted

Date: 2026-07-01

**Amended: 2026-07-02** (in place, pre-implementation — no code had been written against it yet). Tightened the Materialized lifecycle after review: **(a)** a plan payment has **no amount/line override** at confirm — it records exactly the server-computed slice (§4); **(b)** a plan is **immutable after creation except cancellation** — there is no mid-life revision of Items/payments; changing terms is cancel + recreate, and `RecurringPaymentCancelled` carries a **refund / no-refund** disposition (§3, §6); **(c)** `Items` are a *contents* statement, **not** an asset valuation (§1); **(d)** a future **Credit** recurring type and item valuation / delivery-cost allocation / FX / inflation are called out as out of scope (§7).

**Amends:**

- **[ADR-0017](./0017-recurring-payment-rules-and-schedules.md) (Materialized schedule structure) and [ADR-0019](./0019-universal-line-items.md) (line-items on the schedule line).** ADR-0017 gave a Materialized `ScheduleLine` a single `ExpectedAmount`; ADR-0019 (universal line-items) turned that into a per-line `list<Line>` breakdown — the code landed as `ScheduleLine { LineId, DueDate, Lines }`, total = Σ `Lines`, i.e. contents held **per payment**. This ADR moves those line-item contents to the **aggregate root** (`Items`) and returns a schedule line to **pure money** (`{ LineId, DueDate, Amount }`). ADR-0019's universal line-items are **retained** everywhere they carry meaning — the root contents, the Live estimate, and the confirmed `FlowRecorded` — and removed only from the intermediate *payment*, which is a scheduled cash amount, not a "what." Everything else in ADR-0017 (the recurrence-rule hierarchy, the two modes, occurrences tracked on the AccountingPeriod, lifecycle) stands unchanged.

**Relates to:** [ADR-0016](./0016-accounting-period-flow-ledger.md) (flow ledger — where confirmed payments land), [ADR-0019](./0019-universal-line-items.md) (`Line`, `Line.WishlistItemId`, the `shipping` tag), [ADR-0022](./0022-wishlist-items-packages-and-derived-status.md) (wishlist items, **Package** grouping, derived **planned/ordered/received** status), [ADR-0024](./0024-category-model.md)/[ADR-0025](./0025-budget-period-centric-and-category-targeted.md) (categories, budgets), [ADR-0008](./0008-multi-currency-and-fx.md) (`CurrencyAmount`).

## Context

A `RecurringPayment` has two schedule modes (ADR-0017). Their treatment of *contents* — the categorised line items that say **what** the money is for — is currently asymmetric:

- **Live** (rent, salary, a subscription) already holds its contents **once**, at the aggregate root, as `EstimateLines`. Every computed occurrence is an instance of that same breakdown.
- **Materialized** (installments, a pre-order) holds contents **per payment**: each `ScheduleLine` carries its own `Lines`. There is no root-level statement of what the plan is buying.

The per-payment placement does not survive a real example. A board-game pre-order: an all-in package (base game + 3 addons) billed in **3 payments of $57**, plus **premium sleeves** and **shipping** charged upfront. The installment split (3×$57) and the product split (base + 3 addons) are **two different partitions of the same money**, and a per-payment line list has room for only one. To itemise the products *and* keep each payment totalling $57, every product must be **fractioned across the payments** — a verbose, lossy encoding from which "what did I buy?" cannot be read back cleanly, and which conflates a *financing* concern (when money moves) with a *purchase* concern (what was bought).

Two further facts shape the fix:

1. **The purchase/grouping/status layer already exists.** [ADR-0022](./0022-wishlist-items-packages-and-derived-status.md) models fine-grained `WishlistItem`s grouped into a **`Package`** with a derived **planned → ordered → received** status — using this exact board-game example. Delivery there is *"a planned-purchase line tagged `shipping`… it has no wishlist item."* A money line reaches that world through **`Line.WishlistItemId`** (ADR-0019). So "what's in the package," the grouping, and order status are **not** a payment-plan concern to invent — they belong to the wishlist/package layer, reached by reference.
2. **The ledger is cash-based.** A confirmed payment is a real cash movement recorded on the AccountingPeriod (ADR-0016) with categorised `Line`s (ADR-0019) that feed budgets (ADR-0025). Whatever a payment records must be categorised.

The forces: make contents legible and stored once; keep a payment a pure cash fact; keep budgets exact; and connect to the existing package/status layer rather than duplicate it.

## Decision

### 1. Both modes capture their contents once, at the aggregate root

The contents of a recurring payment live **once**, on the aggregate, in *both* modes:

- **Live** — `EstimateLines: IReadOnlyList<Line>` (unchanged). Each computed occurrence is an instance of this breakdown.
- **Materialized** — a new root **`Items: IReadOnlyList<Line>`**: the itemised statement of *what the plan is buying* (base game, addon ×3, sleeves, …), each `Line` with its own `CategoryId` and — when it links to the desire/package layer — its `WishlistItemId` (ADR-0019/0022).

"What did I buy?" is answered directly by the item list, with real categories, in both modes.

`Items` are a **contents** statement — *what* was bought and its category — **not an asset valuation**. Pricing the bought thing, allocating a delivery cost across the goods, and any FX/inflation adjustment are **not** a payment-plan concern; they belong to the future packaging layer (§5) and are out of scope here (§7). The near-term concrete need on top of contents is capturing a **delivery cost**, and that is a separate `shipping`-tagged entry (§5), not an `Item`.

### 2. A Materialized payment carries money only

A schedule line is reduced to pure money:

```
ScheduleLine(Guid LineId, DateOnly DueDate, CurrencyAmount Amount)
```

The `Lines` collection (added to the schedule line by ADR-0019) is removed. A payment is a **when-and-how-much**, nothing more. No item lives "inside" a payment; payment amounts may vary (a debt paid $100/$50/$50), but every item in the plan is financed by the *whole* schedule. This restores the schedule line to a single amount — a scheduled cash fact — while the line-item detail lives once at the root (§1) and again on the actual `FlowRecorded` at confirm (§4).

### 3. Balance invariant

For a Materialized plan, **Σ `ScheduleLines.Amount` = Σ `Items.Amount`** (same currency, ADR-0008). A plan must be balanced to be `Active`; an unbalanced plan is rejected. The Materialized body (Items + payments) is authored as a **validated whole at creation** — a single balanced submission — and is **immutable thereafter except cancellation** (§6): there is no add/edit/remove of individual items or payments over the plan's life, so the two sides can never drift out of balance. The client assembles a balanced plan and submits it once; a "split evenly" helper and a running "left to schedule" balance are UI affordances over this invariant. To change a plan's terms, cancel it and create a new one (§6).

### 4. Confirm records a proportional slice of the contents

Because a Materialized payment is a *portion* of the whole (unlike a Live occurrence, which is a full instance), confirming a payment of amount **P** against a plan whose items total **T** records a `FlowRecorded` (ADR-0016) whose lines are the root **`Items` scaled by P/T** — preserving each line's `CategoryId` (and `WishlistItemId`). The slice is **computed server-side, deterministically from the planned schedule**, so cumulative exactness is guaranteed by construction and no per-item state need be read back from the ledger: the allocation to an item after the *k*-th scheduled payment is `round(itemTotal × (Σ payments 1..k) / T)`, and payment *k*'s recorded slice is `cumulative(k) − cumulative(k−1)`. Each payment's lines therefore sum exactly to **P** (largest-remainder within the payment), and the **cumulative** per-item (and per-category) total over the plan's life equals the items exactly, independent of the order payments are confirmed in. Budgets stay exact.

A Materialized payment has **no amount/line override** at confirm — it records exactly this computed slice. (`ConfirmOccurrenceRequest.Lines` override remains a **Live-only** affordance — the utilities −$200→−$180 case; a deterministic installment has no such need.) The schedule is fixed for the plan's life (§3).

For a plan whose items share one category (the common case — the board-game pledge is all *Board games*), this is trivially "the whole payment, that category."

Proportional allocation assumes **every item is financed by the full schedule** — a plan is *one uniformly-financed purchase*. A cost paid outside that scheme — an upfront extra (premium sleeves paid in full now), a shared delivery charge — is **not an item of this plan**; it is its own entry (a one-off, or a `shipping`-tagged line), reunited with the plan later by the Package grouping (§5). This is why the pledge's items are the four game things at $171 over 3×$57, and the sleeves/shipping are separate: mixing an upfront-paid item into the schedule would make a uniform proportional slice wrong.

### 5. Grouping, "what's in it," and order status come from ADR-0022 — not from here

The payment plan does **not** model packages, fulfilment, or shared-cost allocation. Those are the wishlist/package layer:

- A root `Item` `Line` **may** carry `WishlistItemId` (ADR-0019) → a `WishlistItem` that belongs to a `Package` (ADR-0022). Grouping ("these belong together") and **planned → ordered → received** status are ADR-0022's derived projection, driven by the `FlowRecorded`s that confirming payments emit.
- **Shipping / delivery is a line, not an item and not a wishlist item** — a `shipping`-tagged `Line` (ADR-0019/0022). Its proportional allocation across the shipped goods is a purchase-side concern (ADR-0022), not a payment-plan one.
- A `Package` may group items **across** several recurring payments and one-off entries (the sleeves bought outright, the shipping line) — which is why the grouping cannot live on any single payment plan.

### 6. Events

`RecurringPaymentCreated` (Materialized) carries the root **`Items`** and the **money-only** schedule — the plan is authored once, here. The granular `ScheduleLineAdded/Edited/Removed` of ADR-0017 are **removed** for Materialized and are **not** replaced by a revision event: a plan is **immutable after creation except `RecurringPaymentCancelled`**, which gains a **refund / no-refund** disposition (a refund being a subsequent income flow; its mechanics are a later concern, but the flag belongs on cancel now). Header-only edits (name, category) via `RecurringPaymentEdited` are unaffected — they touch no items or amounts. Changing a plan's terms is **cancel + create a new plan**. Live's events are unchanged. No per-occurrence events (ADR-0017 stands).

### 7. Explicitly out of scope (future)

- **Credit / loan as its own recurring type.** This Materialized plan is deliberately **interest-free** — `Σ payments = Σ items`. A bank credit does not fit: it carries **interest** (total repaid > principal, so payments no longer sum to items) and supports **prepayment that re-amortizes the remaining interest** — neither expressible here. Interest must **not** be shoehorned into `Items` (that re-introduces the financing-vs-contents conflation this ADR removes). When built, a dedicated **Credit** type would model **principal + rate + term → a derived amortization schedule** (each payment split principal/interest), a **`prepay`** operation with the standard policy choice — **reduce term** (same installment, fewer of them) vs **reduce installment** (same term, smaller each) — and, on opening, register the **initial loan principal as an income flow** (the money received), with the schedule as the subsequent outflows. Until it exists, a real prepayment is handled by cancel + recreate (§6). Not modeled now.
- **Item valuation, delivery-cost allocation, FX & inflation.** `Items` state contents, not worth (§1). Pricing the bought asset, splitting a delivery charge proportionally across the goods, and adjusting recorded amounts for FX rate or inflation belong to the packaging layer (§5) / Phase-3 asset work. The near-term step is only capturing a delivery cost as a separate `shipping`-tagged entry (§5); valuation/FX/inflation are later.
- **"In route" + approximate arrival date.** ADR-0022's status stops at `Ordered` (paid, awaiting receipt) → `Received` (Phase-3 asset). A finer *in-transit + ETA* fulfilment state is a future refinement (Phase-3 asset/receipt, or a later ADR) — not modeled now.
- **`Line.WishlistItemId` as a live field.** It is specced (ADR-0019/0022) but currently only named in a `Line` code comment; it becomes a real field when the wishlist/package service lands. This ADR assumes that seam, and does not require it to be populated for a plan to function (an item with no `WishlistItemId` is just a categorised amount).

## Consequences

Positive:

- Symmetry: both modes state their contents once, at the root; "what did I buy?" is a direct read with real categories.
- A payment is a pure cash fact — no fractioning of products across installments, no conflation of financing with purchase.
- Budgets stay exact via proportional confirm-time allocation (computed, not stored).
- Clean seam to the existing package/status layer (ADR-0022) via `Line.WishlistItemId`; grouping and order status are not duplicated here.
- Re-aligns the schedule line with ADR-0017's original written intent.

Negative:

- A schema/event change to the Materialized half of a built, tested feature (aggregate field, `ScheduleLine` shape, create path, `RecurringOccurrences` resolution, confirm endpoint, occurrences projection, tests). The per-line edit path (`ScheduleLineAdded/Edited/Removed`) is **removed** outright, not reshaped. Event shapes change — acceptable pre-production (no stored data to migrate), but it *is* a break.
- Confirm now computes a proportional allocation (with largest-remainder rounding) instead of reading stored per-payment lines — a small amount of real logic, and the "fractioning" removed from authoring reappears, computed, at confirm time.
- The balance invariant couples Items and payments; the Materialized body is authored as a validated whole at creation and is **immutable thereafter** (cancel + recreate to change terms), which is stricter than piecemeal editing but keeps the invariant trivially intact.

Neutral:

- Live mode (`Rule` + `EstimateLines`) is untouched.
- The order/fulfilment questions ("in route", proportional shipping cost) are deferred to ADR-0022 + Phase-3 asset tracking, by design.

## Alternatives Considered

1. **Keep contents per payment (ADR-0017 + 0019 as implemented).** Rejected: forces product-vs-payment fractioning, can't answer "what did I buy," conflates financing with purchase.
2. **Confirm as one coarse line** (plan name + "payment n of m", header category) instead of a proportional slice. Rejected: discards the item/category detail that moving contents to the root exists to capture; budgets would see the plan, not the goods. Kept as a fallback only if allocation proves not worth the rounding logic.
3. **Fraction items across payments and store them** (each payment keeps a scaled copy of the items). Rejected: verbose, lossy, and re-introduces the two-partition conflation as stored data; allocation belongs at confirm time, computed.
4. **A new Package/Shipment aggregate owned by the payment plan.** Rejected: ADR-0022 already models `Package` grouping + derived status, spanning multiple purchases; a payment plan is the wrong (too narrow) home for a grouping that includes outright-bought and shipping lines. Reference it via `Line.WishlistItemId` instead.
5. **Model "in route" + ETA now.** Rejected as premature: it is a fulfilment concern beyond ADR-0022's current Ordered/Received and belongs with Phase-3 asset/receipt work.
6. **Handle bank-credit prepayment by mutating the installment plan (a generic `prepay` that re-splits remaining payments).** Rejected: with no interest model the recompute is naive cash redistribution and can't shrink the interest portion a real re-amortization does; and adding interest to make it work would break `Σ payments = Σ items` and re-conflate financing with contents. Credit is its own type (§7), not a mutation of the interest-free plan.
7. **Allow editing / amount-override on a plan (mid-life revision, or a different actual at confirm).** Rejected for the deterministic installment case: a plan's terms are fixed, so override invites drift for no real scenario; the plan is immutable-except-cancel (§3, §6) and Live keeps its override for genuinely variable amounts (utilities).

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. It was amended **once in place on 2026-07-02** under the narrow exception that no code had yet been written against it (see Status); that window is now closed. To change the decision from here, write a new ADR that **Supersedes** this one — do not edit this file.
