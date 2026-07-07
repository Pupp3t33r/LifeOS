# ADR-0029: Materialized RecurringPayment — priceless plan contents, payments are the total, confirm records a plain reference (supersedes ADR-0028 §3–§4)

## Status

Accepted

Date: 2026-07-07

**Supersedes** parts of [ADR-0028](./0028-recurring-contents-at-root.md):

- **§3 (balance invariant)** — dropped. A Materialized plan's payments no longer have to sum to its items. The plan's total is **Σ payments** (emergent); items carry no cost that must balance.
- **§4 (confirm records a proportional slice)** — dropped. Confirming a payment records a **plain reference** to the plan (a single categorised line at the amount actually paid), not a proportional slice of priced items. `ProportionalAllocation` and `SliceForOccurrence` are removed.

**Amends** ADR-0028:

- **§1 (Items at the root)** — retained, but a Materialized `Item` is now **priceless contents**: a description, an *optional, informational* reference value (MSRP-ish), a category, and a future wishlist link. It states *what* the plan buys, never *what it cost*.
- **§6 (events)** — `RecurringPaymentCreated` (Materialized) carries the priceless `Items` shape below. Immutability-except-cancel and the cancel refund/no-refund disposition **stand**.
- **§7 (out of scope)** — item valuation stays deferred; this ADR names the concrete future approach (an MSRP-weighted split of the actual total, §5).

**Retains** ADR-0028 unchanged: **§2** (a payment carries money only — `ScheduleLine { LineId, DueDate, Amount }`), **§5** (grouping / "what's in it" / order status come from ADR-0022 via `Line.WishlistItemId`, not the plan), and the **Credit-type / FX / inflation** out-of-scope calls in §7. Live mode (`Rule` + `EstimateLines` + per-occurrence confirm override) is untouched.

**Relates to:** [ADR-0016](./0016-accounting-period-flow-ledger.md) (flow ledger — where a confirmed payment lands), [ADR-0017](./0017-recurring-payment-rules-and-schedules.md) (the two schedule modes), [ADR-0019](./0019-universal-line-items.md) (`Line`, `Line.WishlistItemId`), [ADR-0022](./0022-wishlist-items-packages-and-derived-status.md) (wishlist items + packages), [ADR-0024](./0024-category-model.md) (categories), [ADR-0010](./0010-asset-aggregate.md) (Phase-3 net worth — where per-item valuation lands).

## Context

ADR-0028 moved a Materialized plan's contents to the aggregate root as **priced** `Items` and enforced **Σ payments = Σ items**, so that confirming a payment could record a **proportional slice** of those priced items — keeping per-category budgets exact.

That model does not survive contact with the purchases it targets. A Materialized plan is almost always an **all-in, discounted deal** — a board-game pledge, a bundle, a pre-order — where:

- **The individual items were never priced individually.** The user paid one negotiated total; the "per-item cost" is a fiction the deal never quoted. Requiring per-item costs at authoring is tedious data-entry of numbers the user does not have, and any split he *invents* is arbitrary.
- **The discount is not attributable per item.** Σ payments (what he actually pays) is the real, known number; Σ of any per-item prices is not — and forcing them equal (the balance invariant) makes the user reconcile two figures that have no reason to match.
- **Per-item cost, when it is ever needed at all, is a net-worth concern** (Phase 3, ADR-0010) — and there it is better **derived** (weight the real total by a reference price like MSRP) than hand-entered.

So the authoring model should be: **items are contents, payments are the money.** The plan's total is what you schedule to pay; the items are just *what's in it*, optionally annotated with a reference value for a future valuation. Confirming a payment is a cash fact against the plan — not an itemisation.

## Decision

### 1. A Materialized item is priceless contents

The root `Items` list stays (ADR-0028 §1), but an item is no longer a `Line` (which carries a mandatory signed `Amount`). It is a distinct, priceless shape:

```
PlanItem(
    string?         Description,
    CurrencyAmount? ReferenceValue,   // optional, informational — MSRP or similar
    Guid?           CategoryId,
    Guid?           WishlistItemId)   // Phase-2 link (ADR-0019/0022)
```

`ReferenceValue` is **informational only**: never validated, never summed, never required, and free to be any currency (typically the plan's). It exists so a future valuation (§5) has something to weight by; a plan with no reference values anywhere is fully valid. `CategoryId` and `WishlistItemId` carry the same meaning as on `Line`.

### 2. The plan total is Σ payments — no balance invariant

A plan's total is **emergent** from its schedule: `Σ ScheduleLines.Amount`. There is **no** relationship enforced between payments and items (ADR-0028 §3 dropped). The client shows the running plan total as a live sum of the payments the user enters; items add up to nothing. Validation on create is only: at least one payment, each payment non-zero, all payments in the plan's currency, unique line ids (ADR-0028 §2 payment rules stand). Items require only that the list is present; a priceless item needs no amount check.

### 3. Confirm records a plain reference, not a slice

Confirming a Materialized payment records a `FlowRecorded` (ADR-0016) with **a single line**:

- **Amount** = the amount actually paid. It **defaults to the scheduled payment's amount** and is **adjustable at confirm** (paid-less / paid-more) — the user's real "this is what I actually paid" number. *(This is the one relaxation of ADR-0028 §4's no-override; it is an amount-only adjustment, never an itemisation.)*
- **CategoryId** = the plan's `CategoryId`.
- plus the `{ recurringId, occurrenceRef }` back-ref (ADR-0017) so the occurrence reads as paid.

There is **no per-payment itemisation and no proportional slice**. To answer "what's in this?", follow the back-ref to the plan and read its `Items`. `ProportionalAllocation` and `RecurringPayment.SliceForOccurrence` are deleted; `RecurringOccurrences.TryResolve` returns the single reference line for the Materialized branch.

Consequence for budgets: a Materialized plan attributes its spend to **one** category (the plan's), not per-item. For "one uniformly-financed purchase" (ADR-0028's own framing) that is the correct granularity; fine-grained per-item categorisation was the thing the priced-slice model bought, and it is deliberately given up.

### 4. Live is unchanged; its flexibility is at pay time

Live stays a recurrence rule + `EstimateLines`, authored once. The plan definition is **not** editable mid-life (no template-edit feature — explicitly not built now, ADR-0028 §6 immutability spirit). The flexibility the user wants on a Live series happens **at confirm**, per occurrence, via the existing Live-only override (`ConfirmOccurrenceRequest.Lines`): pay only some of the estimate lines, adjust the amount, and the occurrence is confirmed. Nothing here changes that.

### 5. Per-item cost is a deferred, derived valuation (Phase 3)

When net worth / assets land (ADR-0010, Phase 3), an item's cost basis is **computed, not stored**: split the plan's **actual total** (Σ confirmed payments) across its items weighted by `ReferenceValue` —
`itemCost = actualTotal × item.ReferenceValue / Σ ReferenceValue`
— i.e. distribute the real (discounted) money by MSRP share. Items without a reference value are handled by whatever policy that phase settles (even split of the remainder, or excluded). This is out of scope now (ADR-0028 §7 stands); the only thing this ADR does for it is **store `ReferenceValue`** so the input exists.

### 6. Events

`RecurringPaymentCreated` (Materialized) carries the priceless `Items` (§1) and the money-only schedule (ADR-0028 §2). The plan remains **immutable after creation except `RecurringPaymentCancelled`** (which keeps its refund/no-refund disposition, ADR-0028 §6); header-only `RecurringPaymentEdited` (name/category) is unaffected. Live events are unchanged. **Event break** — `RecurringPaymentCreated.Items` changes from `list<Line>` to `list<PlanItem>` and the balance invariant is gone. Pre-production, no stored data to migrate: **reset the local `money-db` volume** (same operational note as ADR-0028's breaks).

## Consequences

Positive:

- Matches how all-in deals actually work: one real total (Σ payments), contents that are *listed* not *priced*. No tedious, fictional per-item cost entry.
- A payment plan is simpler end to end: no balance to reconcile, no proportional-allocation logic, no rounding machinery. `ProportionalAllocation` + `SliceForOccurrence` are deleted.
- Confirm is a plain cash fact against the plan — trivially correct, and the actual-paid amount is honest (adjustable).
- The valuation input (`ReferenceValue`) is captured cheaply now; the derivation is deferred to the phase that actually needs it.

Negative:

- A Materialized plan attributes spend to a single category, losing the per-item category granularity ADR-0028's slice provided. Accepted: a plan is one uniformly-financed purchase.
- Another pre-production event break on the same feature (Items shape, create path, confirm/resolve path, occurrences read, tests). Acceptable — no stored data — but it *is* a break, and it partially reverses an ADR from six days earlier.
- Per-item cost is now unavailable until Phase 3, and only as a derived estimate. Intended.

Neutral:

- ADR-0028 §2 (money-only payment) and §5 (grouping via ADR-0022) are untouched and still do their jobs.
- Live mode is untouched.

## Alternatives Considered

1. **Keep ADR-0028 (priced items, balance invariant, proportional slice).** Rejected: forces fictional per-item pricing on discounted all-in deals and reconciliation of two figures that have no reason to match; the per-item budget granularity it buys is not worth the authoring burden for the plans this mode targets.
2. **Priceless items, but confirm still itemises** (copy the priceless items onto the flow as zero/estimated lines). Rejected: a flow line needs a real amount; there is no honest per-item amount to record, and the user explicitly does not want per-payment itemisation. Confirm references the plan instead (§3).
3. **Store per-item cost at confirm** (let the user itemise the actual payment). Rejected per the user's decision — "no per-payment itemisation, just a reference to the plan; items live there." Real per-item costs, if ever needed, are derived at valuation (§5), not entered.
4. **Drop `ReferenceValue` too** (items are pure names). Rejected: keeping an optional reference value costs nothing now and is the input the Phase-3 MSRP-weighted valuation needs; without it that derivation has no basis.

> Note: this ADR adopts what ADR-0028 §Alternatives #2 ("confirm as one coarse line") rejected. The reversal is justified because the premise changed — with items now priceless there is no slice to compute, and the coarse single-line reference is not a lossy shortcut but the correct record of a cash payment against a plan whose contents live at the root.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen — supersede via a new ADR, never edit. It supersedes ADR-0028 §3–§4 and amends §1/§6/§7; the rest of ADR-0028 stands.
