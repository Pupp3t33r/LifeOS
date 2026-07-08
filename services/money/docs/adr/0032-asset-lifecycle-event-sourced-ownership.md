# ADR-0032: Asset lifecycle — event-sourced ownership

## Status

Accepted

Date: 2026-07-08

**Supersedes:**

- The **lifecycle, event set, status enum, and net-worth membership** of [ADR-0010](./0010-asset-aggregate.md). The Asset is confirmed as an **event-sourced aggregate** (ADR-0010 Alternative 4 stance) and its shape is now fixed — resolving the README **Deferred decisions** row *"Asset aggregate shape (bundle→Asset granularity, `AssetTracked` event, Asset fields)."* ADR-0010's **financial-fields-only** principle, the `{ ServiceType, ExternalId }` reference pattern, the `AcquiredCost` vs `CurrentEstimatedValue` split, the two origins (tracked purchase + pre-existing import), and the net-worth **composition** (Liquid + Assets + Debts) all **stand**; only the details below change.

**Amends:** none beyond the ADR-0010 supersession.

**Relates to:** [ADR-0031](./0031-order-aggregate-ancillary-costs-and-receipt.md) (receipt forms Assets; ancillary allocation; late-fee adjustment), [ADR-0030](./0030-external-domain-linking-and-wishlist-creation.md) (the `ExternalRef` the Asset inherits), [ADR-0022](./0022-wishlist-items-packages-and-derived-status.md) (`Received` status), [ADR-0008](./0008-multi-currency-and-fx.md) (`CurrencyAmount`, FX for gain/loss), [ADR-0009](./0009-savings-accounts-and-month-close.md) (Liquid net worth).

## Context

ADR-0010 sketched an `Asset` aggregate (financial fields only) with states `Owned / ListedForSale / Sold` and events `AssetTracked / AssetImported / AssetRevalued / AssetListedForSale / AssetSold / AssetDeleted`, and **deferred its concrete shape to Phase 3**. Two ADRs since then rewired only its *ingestion*: ADR-0018 replaced the PurchaseOrder→Received path with "paid entry → Asset directly," and ADR-0031 replaces *that* with formation at `OrderReceived`. The shape itself — states, events, net-worth membership, granularity — is decided here, its forcing function (the board-game acquisition flow) having arrived.

Forces at play (session decisions):

- **The Asset is born at receipt.** An in-transit purchase is money spent on something **not yet owned**, whose cost is **not yet final** (customs, warehouse→door may still be billed). So `Ordered`/`Arrived` are **procurement** states on the Order (ADR-0031), never asset states, and an **in-transit thing does not count toward net worth.**
- **Drop `ListedForSale`.** This is a personal collection, not a shop; whether an item is "listed" is not tracked — it is still on the shelf, still `Owned`.
- **The possession lifecycle is not Money's concern.** Marking a board game *loaned to a friend* (or its condition, or that it has been played) has **no financial effect** — the item is still owned, net worth unchanged. Recording it in a finance app is the wrong home; it belongs to the app that owns the thing (Board Games, Books). Money holds only events that change **value or net-worth membership**. The **net-worth-effect test** is the boundary: no effect → domain app; effect → Money.
- **Late costs adjust basis.** A customs fee billed after receipt must raise the asset's acquired cost without un-receiving it.

## Decision

### Asset aggregate — event-sourced, financial fields only

Stream `asset/{OwnerId}/{AssetId}`, event-sourced, **not** locked at close (assets live for years after any period closes). Financial fields only (ADR-0010 stands): `ServiceType`, `ExternalId`, `AcquiredDate`, `AcquiredCost: CurrencyAmount`, `CurrentEstimatedValue: CurrencyAmount` (the honesty valve), `OrderId?`, and the payment/sale links below. No descriptive metadata — that stays in the domain service.

### Two origins

- **`AssetAcquired`** `{ AssetId, OwnerId, ServiceType, ExternalId, OrderId, FinalAcquiredCost, AcquiredDate }` — emitted by `OrderReceived` (ADR-0031), **one per received goods line**. `FinalAcquiredCost` is the confirmed allocation (item price + its share of ancillary costs). Replaces ADR-0010's `AssetTracked`.
- **`AssetImported`** `{ AssetId, OwnerId, ServiceType, ExternalId, AcquiredDate, AcquiredCost }` — pre-existing item the user already owned; no `OrderId`, no payment, touches no period. **Stands from ADR-0010.**

Both births land the asset in `Owned`.

### Lifecycle events

```
AssetAcquired    { … }                                              // → Owned   (from Order receipt)
AssetImported    { … }                                              // → Owned   (pre-existing)
AssetCostAdjusted{ Delta: CurrencyAmount, Reason, PaymentFlowRef? } // late ancillary fee (ADR-0031)
AssetRevalued    { CurrentEstimatedValue: CurrencyAmount }          // honesty valve
AssetSold        { SoldFlowRef, SoldFor: CurrencyAmount, SoldAt }   // → Sold
AssetWrittenOff  { Reason: Lost | Trashed | Gifted, Date }          // → WrittenOff
```

### Derived status

`Owned → Sold | WrittenOff`. There is **no `Ordered`** (birth is at receipt) and **no `ListedForSale`** (dropped). **Possession states that move no value — loaned-to-a-friend, condition, played — are not Money's concern**; they live in the owning domain app (Board Games, Books). In Money a physically loaned item is simply still `Owned`.

### Net worth

The **Assets** component = `Σ CurrentEstimatedValue` over assets in **`Owned`**, converted to display currency (ADR-0008). This **supersedes** ADR-0010's `Owned + ListedForSale` set. A physically loaned item is still `Owned`, so it is still counted — Money never learns it was lent out. `Sold`, `WrittenOff`, and anything still in-transit (no asset yet) are excluded. Liquid (ADR-0009) + Assets + Debts composition otherwise stands.

### Gain/loss on sale

`gain_or_loss = SoldFor − AcquiredCost`, each converted to display currency at its own date's rate (`AcquiredDate` for cost, `SoldAt` for proceeds), projection-computed (ADR-0010 stands). `AcquiredCost` now **includes** allocated ancillary costs and any `AssetCostAdjusted`, so the stat reflects true landed cost.

### Granularity: one Asset per received goods line

A received order produces **one Asset per goods line**, not one per bundle — resolving ADR-0018's deferred granularity question in favor of per-item (the reason ADR-0022 chose fine-grained wishlist items: independent per-item status and resale). A priceless pledge's items each become their own Asset via ADR-0031's even-split allocation.

## Consequences

Positive:

- The Asset shape is fixed and event-sourced: a clean per-item stream from acquisition to disposal, matching the "what happened when" goal.
- The finance app stays financial. Possession states (loans, condition, played) live with the thing in its domain app; Money holds only value-moving events. The net-worth-effect test keeps the boundary clean.
- Net worth is honest — in-transit purchases (owned by nobody yet, cost not final) don't inflate it; only currently-owned items are summed.
- Landed cost (with shipping/customs folded in, plus late adjustments) makes bought-vs-sold accurate.
- Per-item granularity gives independent resale and status tracking without a bundle type.

Negative:

- Net worth **dips during transit** (cash gone, asset not yet born). Accepted and intended — it reflects real exposure (the box may never arrive; customs is unknown) until receipt.
- Supersedes ADR-0010's shape and is the third rewiring of its ingestion path (0010 → 0018 → 0031/0032). The chain must be read together; this ADR is the terminal shape.

Neutral:

- `AssetImported` keeps a no-payment door for pre-existing items (unchanged from ADR-0010).
- `WrittenOff` unifies ADR-0010's `AssetDeleted` with a `Reason` (lost / trashed / gifted); a written-off asset leaves net worth with no sale proceeds.

## Alternatives Considered

1. **Asset born at order (an `Ordered` asset state).** Rejected this session: an in-transit item is not owned and its cost is not final; modeling it as an asset forces in-transit net-worth and void-on-cancel special cases. `Ordered`/`Arrived` belong on the Order (ADR-0031); the Asset begins at receipt.
2. **Keep `ListedForSale`.** Rejected: irrelevant to a personal collection — a listed item is still on the shelf and still `Owned`. Not worth a state.
3. **One Asset per bundle/pledge (coarse granularity).** Rejected: loses per-item resale and status (the same reason ADR-0022 chose fine-grained items). One Asset per received line.
4. **Block receipt until all fees (customs) are known.** Rejected: the box is in hand; make it `Owned` and post an `AssetCostAdjusted` when the late fee arrives (ADR-0031). Event sourcing makes the adjustment clean and auditable.
5. **Model Asset as a projection, not an aggregate.** Rejected (as in ADR-0010 Alt 4): revaluation, loan, sale, and write-off are auditable financial events that belong in a stream.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
