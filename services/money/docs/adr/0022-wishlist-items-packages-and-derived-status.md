# ADR-0022: Wishlist items, packages, and derived status

## Status

Accepted

Date: 2026-06-27

**Supersedes:**

- The **`WishlistItem` row of [ADR-0005](./0005-aggregate-boundaries.md)** (modeled there as an event-sourced aggregate on `wishlist/{WishlistItemId}`). Wishlist is re-modeled as **non-event-sourced documents** with a **derived-status projection** (this ADR).

**Relates to:** [ADR-0018](./0018-planned-purchases-on-accounting-period.md) (`PlannedPurchaseAdded` lines reference wishlist items), [ADR-0019](./0019-universal-line-items.md) (`Line.WishlistItemId`), [ADR-0010](./0010-asset-aggregate.md) 
(`ordered`/`received` status), [ADR-0013](./0013-user-preferences-and-configurable-month.md) (precedent for non-event-sourced user-authored state), [ADR-0008](./0008-multi-currency-and-fx.md) (`CurrencyAmount`).

## Context

ADR-0005 modeled `WishlistItem` as an event-sourced aggregate. Two problems with that:

1. **Wishlist history is not consumed.** Nobody reads "when did I add this lens to my wishlist?" or folds a stream of wishlist changes. A wishlist item is current-state CRUD — add, edit estimate, repackage, remove. ADR-0013 already established (for `UserPreferences`) that user-authored state whose history is never consumed belongs **outside the event store**, as a plain Marten document. Event-sourcing the wishlist buys auditability nobody reads, at the cost of a stream, events, and a fold per item.

2. **The state the user wants to track — planned / ordered / received — is not a property of the item; it is derived from the period.** A wishlist item becomes "planned" when a `PlannedPurchaseAdded` references it, and "ordered" when a `FlowRecorded` pays that entry. Those are `AccountingPeriod` events (ADR-0016/0018), not wishlist events. Storing status on the item would duplicate period state and require hand-editing the item whenever a plan/pay happens — exactly the "hand-edited every time" cost that is to be avoided. The status must be **derived**.

Separately, the user wants **fine-grained items grouped into packages**: a board-game all-in pledge is base + 3 addons as **four separate wishlist items** sharing a package, each with its own status (base ordered, addon 2 not). This is richer than one composite item and lets the per-item status projection track each part independently.

Forces at play:

- ADR-0013's precedent: non-event-sourced documents for read-current-only user state (UserPreferences, FX rates). Wishlist joins this category.
- The status derivation spans several stores (wishlist docs + period events + future assets). Read-time multi-hop joins would be costly; the status must be a **pre-computed, incrementally-maintained projection** (a denormalized read-model), not a read-time join.
- The line→item reference already exists: `Line.WishlistItemId` (ADR-0019) on `PlannedPurchaseAdded`/`FlowRecorded` lines. The projection consumes those references.
- Delivery is not a desire (you don't "wish" for shipping) — it is a planned-purchase line tagged `shipping` (ADR-0019). It has no wishlist item.
- Editions (deluxe vs retail) are different domain items (different `ExternalReference`); choosing one is the Board Games service's concern. Money records whichever `ExternalReference` + price the user picked.

## Decision

### `WishlistItem` — non-event-sourced document

One Marten document per item:

```
WishlistItem {
  Id:          Guid,            // client-assigned (create-idempotent, ADR-0003-style)
  OwnerId:     string,          // from JWT sub (ADR-0004)
  PackageId?:  Guid,            // optional; the package this item belongs to (≤1)
  ExternalRef?: ExternalReference,  // domain link (e.g., board-games/{bggId}); descriptive metadata lives elsewhere
  Estimate:    CurrencyAmount,  // user-entered (ADR-0008); single currency per item
  Name?:       string,
  Notes?:      string,
  CreatedAt:   DateTimeOffset,
}
```

Read-all = `Query<WishlistItem>().Where(i => i.OwnerId == owner)`. Writes are user-CRUD only (create / edit-desire / delete / repackage). The item document is **not** mutated when the item is planned, ordered, or cancelled — those are period events; status is derived (below).

### `Package` — lightweight grouping document

One Marten document per package:

```
Package {
  Id:       Guid,
  OwnerId:  string,
  Name:     string,             // "All-in pledge", "Base only", etc.
  CreatedAt: DateTimeOffset,
}
```

A package is purely a **desire-side grouping** of wishlist items (via `WishlistItem.PackageId`). It carries no financial state. Package-level concerns on the purchase side (delivery allocation) are properties of planned-purchase lines, not of this document.

### Derived status — `WishlistItemStatus` projection

Status is computed by an **incrementally-maintained projection** (a Marten async/live projection), **not** by read-time joins. One status document per item:

```
WishlistItemStatus {
  ItemId:          Guid,        // matches WishlistItem.Id
  Status:          enum,        // NotPlanned | Planned | Ordered | Received
  PlannedPeriod?:  (Year, Month),
  OrderedDate?:    DateOnly,    // date the item was paid (transitioned to Ordered)
  // ...plus whatever the fold needs (set of active planned-entry refs, paid refs)
}
```

The projection **subscribes to `AccountingPeriod` events** and, for each event, inspects the `Line.WishlistItemId` references, updating only the affected items' status docs. The multi-hop logic (item → planned entry → flow → asset) lives **inside the projection's fold**, run once per event — **not on every read**.

Status transitions the projection produces:

| Triggering event | Effect on the referenced item |
|---|---|
| `PlannedPurchaseAdded` (a line refs item X) | X → `Planned` (+ the period) |
| `PlannedPurchaseCancelled` / `Edited` (removes the ref) | X → `NotPlanned` if no other active planned entry refs it |
| `FlowRecorded` (links a planned entry that refs X) | X → `Ordered` |
| `FlowReverted` | revert |
| (Phase 3) `AssetTracked` / receipt | `Ordered` → `Received` |

v1 uses `NotPlanned`, `Planned`, and `Ordered`; `Received` arrives with Phase 3 (Asset tracking). A wishlist item that is `Ordered` is "paid, awaiting receipt"; once an Asset is created for it, it becomes `Received`.

**Reads** = load the `WishlistItem` doc + its `WishlistItemStatus` doc (1:1 by `ItemId`), zip. Two loads, no graph traversal. The Wallet's wishlist panel reads this zipped view.

A `Package`'s status (e.g., "2 of 4 ordered") is a **derived rollup** over its items' statuses — computed at read time over items sharing the `PackageId` (cheap: a bounded item count per package). Not stored.

### Multi-line purchases and partial fulfillment

A single `PlannedPurchaseAdded` may reference several wishlist items (one per line) — buying a whole package in one order. Conversely, a purchase may reference only some of a package's items (used copy + 1 addon) — the unreferenced items stay `NotPlanned`. Each item's status is derived independently from the lines that reference it.

### Endpoints (CRUD, idempotent by nature per ADR-0013)

- `POST /api/money/wishlist/items` (client-assigned `Id` → create-idempotent)
- `PUT /api/money/wishlist/items/{id}` (edit desire: estimate/name/notes/package)
- `DELETE /api/money/wishlist/items/{id}`
- `POST` / `PUT` / `DELETE /api/money/wishlist/packages/{id}`

### Eventually consistent

The status projection is **eventually consistent** (async). At solo event volume, lag is sub-second. Wishlist status is not a real-time-critical read, so eventual consistency is acceptable.

## Consequences

Positive:

- Wishlist is simple current-state CRUD (no stream, no events, no fold) — matches how it's actually used.
- Status is always derivable and never hand-edited: planning/paying a wishlist item updates its status automatically via the projection.
- Fine-grained items + packages give per-addon tracking without a composite-item type.
- Reads are cheap (doc + status doc, zipped); no read-time multi-hop join.
- Forward-compatible with receipt scanning and Phase-3 asset receipt.

Negative:

- A non-trivial projection (multi-stream, folds over period events to maintain per-item status). Bounded per item and low-volume at solo scale, but it is real write-side infrastructure.
- Eventually-consistent status (sub-second lag). Acceptable for wishlist; would be wrong for a balance-critical read.
- Supersedes ADR-0005's WishlistItem aggregate — requires this ADR's cross-references.

Neutral:

- Money now has three non-event-sourced document stores (UserPreferences, FX rates, Wishlist) alongside its event streams and projections — consistent with ADR-0013's precedent.
- A wishlist item may be referenced by multiple planned entries over its life (planned, cancelled, re-planned); the projection tracks the set and derives status accordingly.

## Alternatives Considered

1. **Event-sourced `WishlistItem` aggregate (ADR-0005 as-is).** Rejected: history is never consumed; it is current-state CRUD; ADR-0013's precedent puts non-ledger user state outside the event store. Event-sourcing buys unused auditability at real cost.
2. **One list-document per owner (`Wishlist { OwnerId, Items[] }`).** Rejected: every mutation rewrites the whole list (load-modify-store) and concurrent phone+desktop edits are last-write-wins on the entire list — could lose items. One doc per item is granular and concurrency-safe per item.
3. **Fold status onto the `WishlistItem` document (the projection writes status into the item doc).** Rejected: couples event-driven projection writes to the user-CRUD document and complicates concurrent edits (the projection and the user both writing the same doc). Separate item doc + status doc keeps the two write paths clean.
4. **Read-time joins (no projection).** Rejected: the multi-hop join (item → planned entry → flow → asset) on every read is costly and grows with event volume. A pre-computed projection eliminates it.
5. **Model A — atomic item + composition descriptor (one item per desire, addons as a descriptor).** Rejected by the user in favor of Model B: fine-grained items give per-addon status tracking, and packages group them. Atomic-with-descriptor would coarsen status to one-per-desire.
6. **`Package` as a field on items (denormalized name) rather than its own document.** Rejected: a package name shared across items needs one editable home; denormalizing duplicates it. A lightweight `Package` document is the clean grouping + name holder.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
