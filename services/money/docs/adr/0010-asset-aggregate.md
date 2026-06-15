# ADR-0010: Asset aggregate (financial fields only)

## Status

Accepted

Date: 2026-06-15

## Context

Phase 3 of the Wallet roadmap (`apps/wallet/PLAN.md`) introduces an **inventory and net-worth surface**: "what do I own, what could I sell, and for how much." This requires Money to track owned items and their financial attributes.

Forces at play:

- Per root AGENTS.md §2, Money owns all financial state. Resale value and ownership status are unambiguously financial.
- Per root AGENTS.md §2, the Books/Board Games/etc. services own the *descriptive* state of the things (title, ISBN, BGG ID, cover, condition). Money must not duplicate that.
- The cross-service reference pattern (`{ serviceType: string, externalId: Guid }`) is already mandated for PurchaseOrder line items (ADR-0005). The same pattern applies cleanly to Assets.
- The user has two distinct ingestion paths for owned items:
  1. **Tracked purchase** — a WishlistItem becomes a PurchaseOrder, advances through Planned → Ordered → Received, and the received PO produces an Asset.
  2. **Pre-existing import** — the user already owns something bought before using the app. They want to record it (purchase date, purchase cost, current estimated value) for net-worth and future "sold-for vs bought-for" tracking, without polluting any past month's flow.
- The user wants a **bought-for vs sold-for stat** when an asset eventually sells. This falls out naturally if both numbers are stored on the Asset.

Architectural alternatives were considered in `apps/wallet/PLAN.md` (composed from domains, derived from Money POs, new dedicated Assets service). The decision here is to add the aggregate inside Money.

## Decision

### Asset aggregate

Add an **`Asset` aggregate** to Money, holding **financial fields only**:

| Field | Type | Notes |
|---|---|---|
| `AssetId` | Guid | Client-assigned per ADR-0003 |
| `OwnerId` | string | From JWT `sub` (ADR-0004) |
| `ServiceType` | string | The domain the item belongs to (e.g., `books`, `board-games`). Required. |
| `ExternalId` | Guid | The domain service's ID for the item (e.g., the Books service's `BookId`). Required. |
| `AcquiredDate` | DateOnly | When the user acquired it |
| `AcquiredCost` | Money | What was paid (in original transaction currency) |
| `CurrentEstimatedValue` | Money | Editable honesty valve — the user's current best estimate |
| `Status` | enum | `Owned`, `ListedForSale`, `Sold` |
| `PurchaseTransactionId` | Guid? | Link back to the Money transaction that bought it (set when produced by a tracked PO; null for pre-existing imports) |
| `PurchaseOrderId` | Guid? | Link back to the Money PO that produced it (null for pre-existing imports) |
| `SoldTransactionId` | Guid? | Set when the asset sells — links to the income transaction |
| `SoldAt` | DateTimeOffset? | When the sale was recorded |
| `SoldFor` | Money? | Sale amount in original sale currency |

Stream key: `asset/{OwnerId}/{AssetId}`.

Money does **not** store: title, ISBN, BGG ID, cover image, condition, publisher, author, player count, or any other descriptive metadata. Those live in the domain service.

### Events

- `AssetTracked` — created via tracked PO receipt (PurchaseOrder advances to Received). Sets `PurchaseTransactionId` and `PurchaseOrderId`. `Status = Owned`.
- `AssetImported` — created via pre-existing import. Does **not** set `PurchaseTransactionId` or `PurchaseOrderId`. Does **not** touch any MonthlyReview. `Status = Owned`. Bypasses month flow entirely (per ADR-0007).
- `AssetRevalued` — `CurrentEstimatedValue` updated. The honesty valve: user enters their best estimate of current resale value.
- `AssetListedForSale` — `Status = ListedForSale`. Optional state; the user is offering but not yet sold.
- `AssetSold` — `Status = Sold`. Sets `SoldTransactionId`, `SoldAt`, `SoldFor`. The linked transaction is recorded on the relevant savings account (income, in the sale's currency, converted via ADR-0008 when aggregated).
- `AssetDeleted` — soft-deleted (e.g., user gave it away, lost it, no sale). No `SoldFor`.

### Gain/loss computation

When `Status = Sold`:

```
gain_or_loss = SoldFor.Amount − AcquiredCost.Amount
              (both converted to user's display currency at their respective date rates per ADR-0008)
```

This is computed by a projection, not stored on the aggregate. Multi-currency conversion uses the rate on `AcquiredDate` for the cost and the rate on `SoldAt` for the sale proceeds.

### Net worth composition

The Phase 3 net-worth view composes:

- **Liquid**: sum of savings account balances (Money, ADR-0009) — already in Money.
- **Assets**: sum of `CurrentEstimatedValue` across all `Owned` and `ListedForSale` Assets — already in Money.
- **Debts**: sum of outstanding installment balances (ADR-0005 InstallmentPlan) — already in Money.

All converted to the user's display currency via ADR-0008. The Gateway BFF may optionally enrich Asset rows with descriptive data from Books/Board Games services for display, but the math never depends on that enrichment.

### Two creation paths in detail

**Path A — Tracked purchase:**

```
WishlistItem → PO (Planned, in month M) → PO (Ordered) → PO (Received)
                                                          ↓
                                              AssetTracked event
                                              (PurchaseOrderId, PurchaseTransactionId set)
```

The PO amount counts in month M's planned purchases (per ADR-0007 MonthProjection). The Asset appears as Owned from the receipt date forward.

**Path B — Pre-existing import:**

```
User adds Asset directly: { serviceType, externalId, acquiredDate, acquiredCost, currentValue }
                                    ↓
                          AssetImported event
                          (PurchaseOrderId and PurchaseTransactionId null)
                          (no MonthlyReview touched)
```

No transaction is synthesized. The Asset exists from the moment of import. The user may edit `AcquiredCost` post-import (another honesty valve).

## Consequences

Positive:

- Money is the single source of truth for net worth — no cross-service aggregation needed for the math.
- Descriptive metadata stays in domain services — no duplication, no coupling.
- Pre-existing import path is clean and does not pollute any month's flow.
- Gain/loss stat falls out naturally from stored fields.
- The `{ serviceType, externalId }` pattern is reused — consistent with how POs reference goods.

Negative:

- The user must update `CurrentEstimatedValue` manually. Without effort, the net-worth view drifts from reality. Mitigation: UI prompts periodic revaluation; future enhancement could pull market data via BFF.
- Money holds opaque IDs it cannot interpret. Debugging requires cross-service lookup. Acceptable: the IDs are immutable references.
- Two creation paths add complexity to the aggregate's invariants. Mitigated by separate event types with clear semantics.

Neutral:

- Asset is its own aggregate on its own stream — consistent with ADR-0005's pattern. Long-lived (potentially years between Owned and Sold), but low write frequency.

## Alternatives Considered

1. **Compose owned items from domain services (Books, Board Games).** Each domain service tracks ownership and resale value; Money's net-worth view fans out via BFF. Rejected: spreads financial state across services, violating Money's role as owner of all financial state. Resale value is financial.
2. **Derive Assets from received PurchaseOrders.** A PO that reaches Received implies an Asset. Rejected: Asset has a multi-year lifecycle (Owned → ListedForSale → Sold) that outlives the PO. Coupling Asset to PO state makes revaluation, sale, and pre-existing import awkward.
3. **New dedicated `LifeOS.Assets` service.** Rejected: adds a 9th service for one feature. The aggregate fits naturally inside Money.
4. **Store Assets as a projection only (not event-sourced).** Rejected: Asset lifecycle events (revaluation, sale) are auditable financial state; they belong in the event stream per Money's "everything financial is event-sourced" stance.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
