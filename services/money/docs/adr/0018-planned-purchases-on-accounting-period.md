# ADR-0018: Planned purchases on AccountingPeriod — period-centric planning

## Status

Accepted

Date: 2026-06-27

**Supersedes:**

- The **`PurchaseOrder` aggregate** of [ADR-0005](./0005-aggregate-boundaries.md) — its row in the aggregate taxonomy, its stream `purchase-order/{PurchaseOrderId}`, and its lifecycle (Planned → Ordered → Received). The PurchaseOrder is not built in v1; its jobs are redistributed by this ADR (planning) and the amendment to [ADR-0010](./0010-asset-aggregate.md) below (fulfillment).
- The **`WishlistItem` row of ADR-0005** (modeled there as an event-sourced aggregate). Wishlist is re-modeled as non-event-sourced documents with a derived-status projection — see [ADR-0022](./0022-wishlist-items-packages-and-derived-status.md).

**Amends:**

- [ADR-0016](./0016-accounting-period-flow-ledger.md) — `AccountingPeriod` gains planned-purchase events (`PlannedPurchaseAdded`, `PlannedPurchaseCancelled`, `PlannedPurchaseEdited`).
- [ADR-0010](./0010-asset-aggregate.md) — the "Tracked" ingestion path: a paid planned entry marked received creates an `Asset` directly, with no PurchaseOrder intermediary.

**Relates to:** [ADR-0007](./0007-monthly-review-and-projection.md) (MonthProjection sources planned purchases from period events), [ADR-0017](./0017-recurring-payment-rules-and-schedules.md), [ADR-0019](./0019-universal-line-items.md) (the `Line` shape), [ADR-0013](./0013-user-preferences-and-configurable-month.md) (period mapping).

## Context

ADR-0005 modeled planned spending as a `PurchaseOrder` aggregate on its own stream (`purchase-order/{id}`, lifecycle Planned → Ordered → Received). ADR-0016 then established the principle that **everything about a month lives on its `AccountingPeriod` stream** — it moved everyday flow actuals off the Account stream onto the period for exactly that reason. Planned purchases are *also* about a month: they are scheduling decisions ("I intend to buy X in March") that reduce that month's projected savings, and the canvas reads them per-month.

Forcing planned purchases into a sibling aggregate (PurchaseOrder) carries three costs:

1. The `MonthProjection` (ADR-0007) must **cross-stream join** PurchaseOrders to periods by `targetMonth` — exactly the chatty composition the period stream was created to eliminate.
2. Each purchase adds a stream, even though the PurchaseOrder's v1 job is almost entirely planning state. The Ordered → Received transitions (the asset-tracking hook) are **Phase 3** and unused in v1.
3. The plan is separated from the month it is planned for, contradicting ADR-0016's "everything about a month in one place."

The planner's real unit is a **planned-purchase entry on a month** — a line-itemed intention that the canvas reads, the user cancels or defers, and (when paid) a `FlowRecorded` confirms. That unit belongs on the period stream, next to the flow actuals it becomes.

Forces at play:

- ADR-0016 already accepted lifecycle + flow on one stream, with concurrent-write contention handled by Marten optimistic-concurrency retry at solo volume. Planned-purchase events are far less chatty than flow entries (a handful per month), so the marginal contention is negligible.
- A period stream **locks at close** (`MonthClosed` rejects further events, per ADR-0007/0016). This is compatible with planning (planning is within-month) but **incompatible with fulfillment** — Ordered → Received → asset tracking happens across period boundaries and after close. Fulfillment therefore cannot live on the period stream; it needs an unlocked home. That home is the **Asset aggregate** (ADR-0010): a paid entry marked received creates an Asset directly. ADR-0010's "pre-existing import" path already bypasses a PurchaseOrder, so dropping the PO-as-fulfillment-vehicle is consistent, not a regression.
- Carrying a planned purchase to the next month at close is a natural period-boundary operation: the closing period locks, and the next period opens with a `PlannedPurchaseAdded` referencing the carried entry; the original remains in the locked snapshot.

## Decision

### Planned purchases are events on AccountingPeriod

Planned spending lives on the `period/{OwnerId}/{Year}/{Month}` stream as events, not as a separate aggregate. New events:

- `PlannedPurchaseAdded { EntryId, Lines: list<Line>, Description?, Origin? }` — adds a planned purchase to this period. `EntryId` is client-assigned (ADR-0003). `Lines` carry the breakdown (the `Line` shape is defined in [ADR-0019](./0019-universal-line-items.md)). `Origin?` is an optional soft reference `{ RecurringId, CarriedFromDate }`, populated by the recurring carry-make-up operation ([ADR-0020](./0020-recurring-live-carry-make-up-defer.md)) and otherwise unused.
- `PlannedPurchaseCancelled { EntryId }` — cancels an entry (terminal for that entry within the period).
- `PlannedPurchaseEdited { EntryId, Lines, Description? }` — edits an unpaid entry in place.

The period is implied by the stream the event is appended to — there is no `targetMonth` field.

**Conversion to paid** = a `FlowRecorded` (ADR-0016) carrying a `{ PlannedEntryId }` back-reference, mirroring how recurring confirmation works in ADR-0017. No separate event. The actual amount/lines may differ from the planned estimate (used copy, fewer addons) — the ADR-0017 "actual adjustable at confirm" pattern, generalized.

Idempotency rides the period's existing `EntryId` invariant (ADR-0003, relocated to AccountingPeriod by ADR-0016): duplicate `EntryId` with identical payload returns 200; conflicting payload returns 409.

### The PurchaseOrder aggregate is removed for v1

ADR-0005's `PurchaseOrder` aggregate (stream `purchase-order/{id}`, lifecycle Planned → Ordered → Received) is **superseded for planning** and is not built in v1. Its two jobs are redistributed:

- **Planning** → `PlannedPurchaseAdded` and friends on the period stream (this ADR).
- **Fulfillment / asset tracking** → the `Asset` aggregate (ADR-0010), per the amendment below.

### Fulfillment / asset tracking goes through the Asset aggregate (amends ADR-0010)

The "Tracked" ingestion path of ADR-0010 is amended: a **paid planned entry** — a `FlowRecorded` linking a `PlannedEntryId`, whose `Lines` carry `ExternalReference`s — can later be marked **received**, which appends `AssetTracked` to the `asset/{AssetId}` stream. The Asset's acquired cost is computed from the paid entry's lines (plus proportional delivery allocation across the entry's item lines). **No PurchaseOrder intermediary.**

ADR-0010's other ingestion path (pre-existing import) is unchanged. Both paths converge on creating an Asset.

The Asset stream is the home for receipt because, unlike the period stream, it is **not locked at close** — assets are received days, weeks, or months after the period closes. The proportional delivery allocation rule (delivery spread across item lines by each line's share of the item-cost total) is captured here as the Phase-3 acquired-cost computation; its full mechanics are deferred to Asset implementation.

### Carrying a planned purchase to the next month

At close, an unpaid planned purchase can be **deferred** (carried to the next period). Because the closing period locks, deferral = the next period opens with a `PlannedPurchaseAdded` referencing the carried entry (via `Origin`); the original stays in the closing period's locked snapshot, whose projection shows it as "carried out." The full disposition rules (cancel vs defer, by attachment type) are the subject of [ADR-0021](./0021-close-flow-multi-account-allocation-and-dispositions.md).

### MonthProjection sources planned purchases from period events

ADR-0007's `MonthProjection` consumes planned purchases from `PlannedPurchaseAdded` / `PlannedPurchaseCancelled` / `PlannedPurchaseEdited` events **on the period stream**, not from a PurchaseOrder stream. The cross-stream PO join is eliminated; planned purchases and flow actuals are read from the same stream.

## Consequences

Positive:

- Planned purchases live where they belong — on the month they are planned for — consistent with ADR-0016's philosophy.
- `MonthProjection` reads planned purchases from the same stream as actuals; no cross-stream join.
- One fewer aggregate in v1 (no PurchaseOrder); the planner's unit (a line-itemed entry) is first-class.
- Fulfillment/asset tracking is cleaner: Assets are created directly from paid entries, reusing ADR-0010's existing direct-creation path.
- Carrying a purchase to the next month is a natural period-boundary event.

Negative:

- Cross-month re-targeting is a **two-stream operation** (cancel here + add there), versus a single `targetMonth` edit on a PO stream. Accepted: re-target is rare, and carry-over is inherently a boundary operation anyway.
- Supersedes ADR-0005's PurchaseOrder aggregate and amends ADR-0010's tracked path — both require this ADR and its cross-references to be read together.
- The period stream gains planned-purchase events alongside lifecycle and flow. Accepted: ADR-0016 already accepted lifecycle + flow on one stream; planned purchases are far less chatty than flow.

Neutral:

- The `PlannedPurchaseAdded.Origin` field exists for the recurring carry-make-up operation (ADR-0020) and is otherwise unused — a forward-compatible optional field.
- A paid planned entry may have multiple item `Lines` with `ExternalReference`s. How a paid entry maps to `Asset`s (one Asset per item line vs. one Asset per bundle) is an **Asset-shape decision deferred to a later ADR**; this ADR commits only to "a paid entry marked received produces Asset(s)," not to the granularity. The Asset aggregate's shape (fields, lifecycle, the `AssetTracked` event) is likewise deferred.

## Alternatives Considered

1. **Keep PurchaseOrder as a separate stream (ADR-0005 as-is).** Rejected: contradicts ADR-0016's "month in one place," forces a cross-stream projection join, and the PO's v1 job is almost entirely planning state (fulfillment is Phase 3). The period stream is the natural home.
2. **Planned purchases on the period stream, but keep a PurchaseOrder for fulfillment (spawned at payment).** Rejected: creates a second object per purchase whose only v1 job is to wait for Phase 3. The Asset aggregate already handles cross-period receipt, and ADR-0010 already supports direct Asset creation. Adding a PO just to delay Asset creation adds an object without a v1 job.
3. **Model planned purchases as a projection over wishlist + recurring, with no period events.** Rejected: planned purchases are user-authored scheduling decisions with lifecycle (add/edit/cancel/defer) and idempotency needs; they deserve events on the period stream, like flow actuals do (consistent with ADR-0016 Alternative 1's rejection of projection-only actuals).
4. **Put fulfillment (Ordered → Received) on the period stream.** Rejected: the period locks at close; receipt happens across period boundaries and after close. Fulfillment needs an unlocked home — the Asset stream.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
