# ADR-0034: Wishlist as built — once/reusable flag, commitment state, and the planned-purchase deadline

## Status

Accepted

Date: 2026-07-10

**Supersedes:**

- The **`WishlistItemStatus` status vocabulary and its derivation table** of [ADR-0022](./0022-wishlist-items-packages-and-derived-status.md) (`NotPlanned | Planned | Ordered | Received`, derived only from `AccountingPeriod` events). This ADR replaces that enum with `Idle | Planned | Financed | Bought` and extends the derivation to `RecurringPayment` membership. ADR-0022's document + package + projection **architecture** — non-event-sourced `WishlistItem` / `Package` documents, a separate incrementally-maintained status projection, per-item granularity, read = doc + status zipped — **stands** and is reaffirmed.

**Amends:**

- [ADR-0022](./0022-wishlist-items-packages-and-derived-status.md) — the `WishlistItem` document gains a **`Recurrence`** (`Once | Reusable`) flag (user-authored, unlike the derived status).
- [ADR-0018](./0018-planned-purchases-on-accounting-period.md) — `PlannedPurchaseAdded` / `PlannedPurchaseEdited` gain a nullable **`Deadline`** (`DateOnly?`); when set, the target period is derived from it.

**Relates to:**

- [Wallet ADR-0005](../../../../apps/wallet/docs/adr/0005-plan-destination-and-planning-views.md) — the consumer. Its Board try-on tray and §9 "once/reusable is the keystone" are exactly what this ADR persists; §9 explicitly defers recording the entity to "Money ADRs as each is built" — this is that ADR.
- [ADR-0019](./0019-universal-line-items.md) — `Line.WishlistItemId`, the reference the projection reads for `Planned` / `Bought`.
- [ADR-0028](./0028-recurring-contents-at-root.md) / [ADR-0029](./0029-recurring-materialized-priceless-contents.md) — `PlanItem.WishlistItemId`, the reference the projection reads for `Financed`.
- [ADR-0013](./0013-user-preferences-and-configurable-month.md) — the period anchor a `Deadline` is bucketed by.

## Context

[Wallet ADR-0005](../../../../apps/wallet/docs/adr/0005-plan-destination-and-planning-views.md) (Accepted 2026-07-08) froze the Plan destination. Its **Board** view — a try-on timeline where idle wants are dragged onto months — depends on a wishlist model that [ADR-0022](./0022-wishlist-items-packages-and-derived-status.md) (Accepted 2026-06-27, before the Order/plan model settled) does not provide. Building the backend forces three divergences between the two Accepted ADRs closed:

1. **No `once`/`reusable` flag.** ADR-0005 §9 makes this flag "the keystone": a **`once`** want (fridge, tires) is schedulable a single time — dragging it out of the tray removes it; **`reusable`** (coffee, tea) stays and each drag spawns an independent planned purchase. ADR-0022's document has no such field. Without it the Board tray cannot decide what to show.

2. **Different status vocabulary.** ADR-0022 derives `NotPlanned | Planned | Ordered | Received`; ADR-0005 speaks of a commitment state `idle → planned | financed | bought`. These are not the same enum, and one (`financed`) has no ADR-0022 transition at all.

3. **`financed` is invisible to ADR-0022's projection.** ADR-0022 derives status only from `PlannedPurchaseAdded` / `FlowRecorded` on the period. A want financed inside a Materialized `RecurringPayment` (a payment plan, referenced via `PlanItem.WishlistItemId`, ADR-0028/0029) never appears in those events, so ADR-0022 would report it `NotPlanned` — but ADR-0005 needs it to leave the tray as `financed`.

Separately, ADR-0005 §8's planned-purchase **deadline switch** ("pick a deadline; the month is derived from it") needs a nullable `Deadline` on the planned purchase. [ADR-0018](./0018-planned-purchases-on-accounting-period.md) has neither the field nor the derive-period-from-deadline behaviour.

Forces at play:

- The flag is **user-authored current state** (the user declares a want once/reusable), not derived — it belongs on the `WishlistItem` document, alongside estimate/name, not in the status projection. This keeps ADR-0022's clean split (user-CRUD doc vs event-derived status doc) intact.
- The commitment state **is** derived, and now spans one more store (`RecurringPayment`) than ADR-0022 anticipated. The projection already folds multi-store references; adding `RecurringPayment` membership is the same shape of work.
- For a `once` want the states are **mutually exclusive** (idle, or on a period, or in a plan, or bought) — the client tray only ever offers idle wants, so the exclusivity is structurally enforced upstream and the projection only ever sees one active commitment per once-item.
- `Deadline` is additive to an existing event; old events deserialize to `null` (no `Deadline`), so it is pre-implementation-cost-free and forward-safe.

## Decision

### `WishlistItem` gains a `Recurrence` flag (amends ADR-0022)

```
WishlistItem {
  ...ADR-0022 fields...
  Recurrence: enum { Once, Reusable },   // default Once; user-authored
}
```

`Once` (fridge, tires): schedulable/buyable a single time. `Reusable` (coffee, tea): stays available; each planning action spawns an independent planned purchase. The create/edit payloads gain `recurrence`; all other ADR-0022 write endpoints (`POST` / `PUT` / `DELETE /wishlist/items`, package CRUD) are unchanged.

### Commitment state — `WishlistItemStatus.Status` becomes `Idle | Planned | Financed | Bought` (supersedes ADR-0022)

One status document per item (ADR-0022's projection, re-vocabularied):

```
WishlistItemStatus {
  ItemId:         Guid,
  Status:         enum { Idle | Planned | Financed | Bought },
  PlannedPeriod?: (Year, Month),   // when Planned
  PlanId?:        Guid,            // when Financed (the RecurringPayment)
  BoughtDate?:    DateOnly,        // when Bought
  // + the fold's working set (active planned-entry refs, plan refs, paid refs)
}
```

- **`Idle`** — no active commitment (ADR-0022's `NotPlanned`). The Board tray shows `Idle` wants (plus all `Reusable` wants regardless of state).
- **`Planned`** — a `PlannedPurchaseAdded` line references it (single-purchase intent on a period).
- **`Financed`** — a `PlanItem.WishlistItemId` in an **active** Materialized `RecurringPayment` references it (ADR-0028/0029). Computable today; this ADR makes the projection derive it.
- **`Bought`** — a `FlowRecorded` line (or a paid planned entry) references it: the single purchase was paid. (`Received`, ADR-0022's fourth state, is deferred to Phase 3 Asset receipt and is **out of scope** here.)

A payment plan pays over time; a `Financed` item **stays `Financed`** for the plan's life in v1 (the per-installment `FlowRecorded` the plan confirm records under the plan's category is *not* a wishlist-line reference, so it does not flip the item to `Bought`). Phase-3 receipt/valuation is where a financed item's ownership is recorded.

### Derivation (updated transition table)

The projection subscribes to `AccountingPeriod` events **and** `RecurringPayment` events:

| Triggering event | Effect on referenced item X |
|---|---|
| `PlannedPurchaseAdded` (a line refs X) | X → `Planned` (+ period) |
| `PlannedPurchaseCancelled` / `Edited` (drops the ref) | X → `Idle` if no other active commitment |
| `FlowRecorded` (a line refs X, or pays a planned entry that refs X) | X → `Bought` |
| `FlowReverted` | reverse the affected transition |
| `RecurringPaymentCreated` (a `PlanItem` refs X) | X → `Financed` (+ `PlanId`) |
| `RecurringPaymentCancelled` | X → `Idle` if that plan was its commitment |
| (Phase 3) Asset receipt for X | `Bought` / `Financed` → `Received` |

For a `Once` item these are exclusive (the tray offers only `Idle` wants, so at most one commitment forms). A `Reusable` item's document status tracks its *latest* commitment but never leaves the tray; each drag is an independent planned purchase, so double-count is impossible.

### Nullable `Deadline` on the planned purchase (amends ADR-0018)

`PlannedPurchaseAdded` / `PlannedPurchaseEdited` gain `Deadline: DateOnly?`:

- **`Deadline == null`** — the target period is chosen directly (ADR-0018 unchanged; "this month", no date).
- **`Deadline` set** — the target period is **derived** from it via the ADR-0013 period anchor. The buy still files to exactly one period; the deadline is display + sort (a `by <date>` chip, sorted ahead of dateless buys). A single client switch (ADR-0005 §8) flips between the two input modes; both are representable, a month/date contradiction is not.

Old events deserialize `Deadline = null`. No migration.

### Board horizon and cross-period reads (no new domain rules)

The Board's *committed weight per month* and the List view's *cross-period planned-purchase* shelf are **read compositions** over existing data (per-recurring `GetOccurrences` in a window + a range-widened planned-purchase query, bucketed by period). They carry **no new domain rules** and are recorded here only as consumers this model enables; their endpoint shapes are an implementation detail, not an ADR decision.

## Consequences

Positive:

- The two Accepted ADRs (Money 0022, Wallet 0005) are reconciled into one persisted model; the Board tray's keystone (`once`/`reusable`) and its idle/planned/financed/bought states exist server-side, derived and never hand-edited.
- `Financed` is now visible (payment-plan membership drives it), so a financed want correctly leaves the try-on tray and shows only as plan weight (ADR-0005 §6).
- The deadline switch is representable additively; no month/date contradiction and no ADR-0018 migration.
- ADR-0022's clean two-document split (user-CRUD item vs derived status) is preserved; the flag rides the user-CRUD doc, the states ride the projection.

Negative:

- The status projection now folds a second event source (`RecurringPayment`), widening its subscription. Bounded per item, low volume at solo scale, but more write-side surface than ADR-0022 sketched.
- Supersedes a frozen ADR's enum — every reference to `NotPlanned/Ordered` must move to `Idle/Bought`. All pre-implementation (no wishlist code exists yet), so the churn is documentation-only.

Neutral:

- `Recurrence` defaults `Once`; existing (none yet) items would read as `Once`.
- `Received` remains reserved for Phase 3; v1 tops out at `Bought`.

## Alternatives Considered

1. **Keep ADR-0022's `NotPlanned/Planned/Ordered/Received` and map to ADR-0005's vocabulary in the Flutter client.** Rejected: two vocabularies for one concept, indefinitely, with `financed` synthesised client-side from a `PlanItem` join the client would have to re-derive on every read. The server is the natural home for a derived state; one vocabulary end-to-end is simpler and less bug-prone.
2. **Model `once`/`reusable` as two document types (or a subtype).** Rejected: it is one boolean-ish flag on an otherwise identical item; a discriminator buys nothing and complicates the CRUD surface.
3. **Store the commitment state on the `WishlistItem` document (user + projection both write it).** Rejected for the same reason ADR-0022 rejected it (Alt. 3): it couples the event-driven projection to the user-CRUD document. The flag (user-authored) goes on the item; the state (derived) stays on the status doc.
4. **A required target-period plus an optional deadline field on the planned purchase.** Rejected (mirrors Wallet ADR-0005 Alt. 6): the single input-mode switch makes a month/date contradiction unrepresentable; two independent fields do not.
5. **Flip a financed item to `Bought` as each installment is paid.** Rejected: a plan's installments are money-only references under the plan's category (ADR-0029), not wishlist-line references, and the item is not "bought" until received. `Financed` is the honest v1 terminal; receipt is Phase 3.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
