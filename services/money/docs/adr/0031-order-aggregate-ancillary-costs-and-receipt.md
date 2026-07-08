# ADR-0031: The Order aggregate — procurement, ancillary costs, and receipt

## Status

Accepted

Date: 2026-07-08

**Supersedes:**

- The **fulfillment/direct-path** of [ADR-0018](./0018-planned-purchases-on-accounting-period.md) ("a paid planned entry marked received creates an `Asset` directly, with no intermediary; delivery allocated proportionally; mechanics deferred"). Receipt now flows through an **Order aggregate**, which coordinates multi-item→multi-asset fan-out, ancillary-cost allocation, a receipt confirmation step, and late fees. ADR-0018's core (planned purchases as period events; the PurchaseOrder stays removed) **stands** — the Order is a fulfillment vehicle, not a planning one.
- The **delivery-as-a-lone-tag** rule of [ADR-0019](./0019-universal-line-items.md) §Line ("Delivery is an ordinary line: `Tag = "shipping"`; its proportional allocation is the Phase-3 computation"). Generalized here to typed **ancillary costs** (shipping, customs, handling, other) with a defined allocation. ADR-0019's `list<Line>` model and the "actual adjustable at confirm" pattern stand.

**Amends:**

- [ADR-0022](./0022-wishlist-items-packages-and-derived-status.md) — fills the deferred receipt trigger in its status table: `OrderPlaced` → referenced items `Ordered`; `OrderReceived` → `Received` (the "(Phase 3) AssetTracked / receipt" stub).

**Relates to:** [ADR-0032](./0032-asset-lifecycle-event-sourced-ownership.md) (receipt forms Assets), [ADR-0016](./0016-accounting-period-flow-ledger.md) / [ADR-0019](./0019-universal-line-items.md) (money stays `FlowRecorded` on periods), [ADR-0024](./0024-category-model.md) (`Line.ExternalRef`, `CategoryId`), [ADR-0030](./0030-external-domain-linking-and-wishlist-creation.md) (the link the Order carries forward), [ADR-0018](./0018-planned-purchases-on-accounting-period.md) (a paid plan is one payment source).

## Context

ADR-0018 removed the `PurchaseOrder` and said a paid entry marked received would create an Asset **directly, with no intermediary** — explicitly rejecting "a second object whose only v1 job is to wait for Phase 3." It deferred the receipt mechanics and the paid-entry→Asset granularity to a later ADR. That ADR's forcing function has now arrived (designing the full board-game acquisition flow), and the direct path proves insufficient: a real receipt has coordination the paid `FlowRecorded` cannot hold —

- **one payment, many assets** (a box of several games) → multi-item fan-out;
- **shared costs** (shipping, and later customs, handling, warehouse→door) that must be **allocated into each item's cost basis**;
- a **receipt confirmation step** where the user confirms or edits the per-item split;
- **late fees** billed *after* the order, on a **different period** (customs at the door);
- **cancel-before-receipt** that must revert the wishlist and never fabricate an asset.

These are substantive coordination jobs, not "an object waiting for Phase 3" — so the object ADR-0018 rightly refused is not the object introduced here.

Forces at play:

- **Money stays period-owned** (ADR-0016): every money movement is a `FlowRecorded` on a period. The Order must *not* become a second money ledger; it **references** the payment(s).
- The **period locks at close** (ADR-0007/0016), but receipt and late fees happen across period boundaries. Fulfillment therefore needs an **unlocked home** — the same reason ADR-0018 sent receipt to the (unlocked) Asset stream. The Order is likewise unlocked.
- Session decisions: model it as a **proper event stream** (clean "what happened when," and a clean seat for partial/split receipt later); **split shipments are post-v1**; a **receipt confirmation window** sets the split; **cancel is decoupled from refund** (refunds sometimes never arrive).
- ADR-0032's decision that the **Asset is born at receipt** means `Ordered`/`Arrived` are **procurement** states on the Order, not asset states.

## Decision

### An event-sourced Order aggregate owns procurement and receipt

Stream `order/{OwnerId}/{OrderId}`, event-sourced, **not** locked at close. An Order is opened for a **goods purchase** — a payment whose lines are destined to become assets (they carry `WishlistItemId` and/or `ExternalRef`). A plain expense opens no Order. The Order **owns no money**; it references the `FlowRecorded` payment(s) on their periods.

Events:

```
OrderPlaced   { OrderId, OwnerId,
                Lines: [ { LineId, WishlistItemId?, ExternalRef, ItemPrice? } ],
                Fees:  [ { Type, Amount } ],
                PaymentFlowRef }                       // the immediate/at-order payment (ADR-0016)
FeeAdded      { Type, Amount, PaymentFlowRef }         // a later fee (e.g. customs), on its own period
EtaSet        { Eta: EstimatedArrival }                // fuzzy month or precise date; may be unset
OrderReceived { ArrivedDate: DateOnly,
                Allocation: [ { LineId, FinalAcquiredCost: CurrencyAmount } ] }   // from the confirm window
OrderCancelled{ }
```

Line procurement state: `Ordered → Arrived` (via `OrderReceived`) `| Cancelled`. **v1 receives the whole order at once**; the event model is chosen precisely so **partial receipt / split shipments** (per-line `LineReceived`, `ShipmentDispatched` grouping) drop in as a **post-v1** extension with no rework.

### The ETA is fuzzy by default

International post rarely gives a delivery day — it gives a month. So the estimated arrival is **month-granular by default, precise only when tracking provides a date**:

```
EstimatedArrival = { Month: (Year, Month) }   // fuzzy — the common case for cross-border post
                 | { Date: DateOnly }         // precise — when tracking yields a day
```

`EtaSet.Eta` may also be **unset** (ordered, no estimate yet). A consumer's rolling "arriving soon" view (e.g. the next 30 days) interprets a month-fuzzy ETA by **overlap** (a `{ August }` ETA is "arriving soon" whenever August intersects the window). Because the Order is its **own stream, not period-scoped** (above), that arriving view is inherently **cross-period** — a package due tomorrow is never hidden because a new accounting period opens tomorrow.

### Ancillary costs, generalized and typed

Shipping stops being special. An `AncillaryCost { Type: Shipping | Customs | Handling | Other, Amount: CurrencyAmount }` is any order-level cost that finances the whole order and **never becomes an asset**. On the **spending ledger** each ancillary cost is still a `Line` on its `FlowRecorded` (ADR-0019), carrying a `CategoryId` — default **inherit the order's item category** (so "spent on board games this month" honestly includes its shipping and customs); a system **"Fees & Delivery"** category is the fallback for a mixed-category order. `Type` is retained metadata for a future fee report, independent of the category.

### Money stays `FlowRecorded`; the Order only references it

- The at-order payment is an ordinary `FlowRecorded` (expense) on the current period — items **and** known fees as its lines (ADR-0019). `OrderPlaced.PaymentFlowRef` links it.
- A **late fee** (customs at delivery) is another `FlowRecorded` on **whatever period it is paid in**; `FeeAdded` links it. A single acquisition may thus straddle two months' ledgers — and the Order is what **reunites** them into one cost basis.
- A **refund**, if it ever comes, is an ordinary **income** `FlowRecorded` linked to the `OrderId`, recorded **if and when** it arrives. It is **never** auto-posted by cancellation.

### Receipt: a confirmation window that pins cost basis

`OrderReceived` carries the **confirmed** per-line `FinalAcquiredCost`, produced by a receipt confirmation window whose **default allocation** is:

> each item's own price **+** its pro-rata share (by item price) of **all** ancillary costs; **even split** when item prices are missing or equal (a priceless pledge, ADR-0029/0030).

The user confirms or edits the split. `OrderReceived` then **triggers `AssetAcquired` per goods line** (ADR-0032), each with its `FinalAcquiredCost`.

### Two lenses on the same money — deliberately different

- **Cost basis (assets / net worth):** ancillary costs are **folded** into each asset's `AcquiredCost` (the allocation above) — so "bought-for vs sold-for" is honest, shipping and customs included.
- **Spending ledger (Home):** shows the **actual payments in the period each occurred** — the order payment in month *M*, the customs charge in month *M+1* — **no retroactive fold** (the ledger records money moving in time; folding would mean editing a closed past month).

### Cancel reverts the wishlist; late fees adjust the asset

- `OrderCancelled` reverts each line's **wishlist item to its prior state** (back in the tray if it was there). No asset is formed (birth is at receipt). Refund is separate and optional (above).
- A fee billed **after** receipt (customs invoice arrives a week later) is a `FeeAdded` that **re-allocates and posts an `AssetCostAdjusted`** on each affected asset (ADR-0032) — the box is in hand, so receipt is not blocked waiting on the fee.

## Consequences

Positive:

- The orphaned receipt/asset-formation step (dropped when ADR-0018 removed the PurchaseOrder) finally has a home, with real coordination the direct path could not carry.
- Money mechanics are unchanged — every movement stays a period `FlowRecorded`; the Order is additive and owns no money.
- Cost basis is honest across time and periods; the Order reunites a split payment into one acquired cost.
- The event model makes partial receipt, split shipments, and late fees clean extensions, not rewrites.

Negative:

- Reintroduces an aggregate between payment and asset — the shape ADR-0018 declined. Justified: its jobs (fan-out, allocation, confirmation, late fees, cancel-revert) are substantive and present in v1, unlike the PurchaseOrder whose v1 job was empty.
- A goods purchase now touches two streams (period `FlowRecorded` + `order/{…}`) plus, at receipt, N asset streams. Accepted at solo volume; the fan-out is bounded by items-per-order.

Neutral:

- v1 receives whole orders; partial/split receipt is designed-for but deferred.
- An Order exists only for goods destined to be assets; the vast majority of expenses open none.

## Alternatives Considered

1. **Keep ADR-0018's direct path (paid entry → Asset, no Order).** Rejected: it cannot hold shared-cost allocation across items, a receipt confirmation step, late fees on another period, or clean cancel-revert. These are real, present in v1, and cross-cutting.
2. **Model the Order as a non-event-sourced document (the ADR-0022 posture).** Rejected this session: its history *is* consumed (ordered→received, partial arrivals, fee timeline) and drives asset formation; event sourcing gives the clean audit and the clean seat for partial/split receipt. (Wishlist stays a document because *its* history is not consumed — different object, different profile.)
3. **Let the Order own the money (its own ledger).** Rejected: violates ADR-0016 (money lives on the period). The Order references `FlowRecorded`s; the period stays the single money ledger.
4. **Auto-post a refund on cancel.** Rejected: refunds are not guaranteed to arrive. Cancel reverts the wishlist and forms no asset; a refund is a separate income entry recorded only if it lands.
5. **Fold ancillary costs into item lines on the spending ledger too.** Rejected: a late customs fee cannot fold into an already-closed month's item line without rewriting history. Fold for cost basis, keep the ledger chronological.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
