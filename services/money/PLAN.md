# Money Service — Plan

> **Purpose:** This file is the evolving roadmap for the Money service. It captures current state, target state, refactor needs, and feature build order. It is **not** frozen (unlike ADRs). Update freely as work progresses.
>
> **Related:** [Money AGENTS.md](./AGENTS.md) for stable conventions; [Money ADRs](./docs/adr/) for frozen architectural decisions; [Wallet PLAN.md](../../apps/wallet/PLAN.md) for the consumer-app roadmap that drives this work.

---

## 1. Current state (as of 2026-06-15)

### Implemented

| Component | State | Notes |
|---|---|---|
| `Account` aggregate | Scaffolded | Per ADR-0005; needs `CurrencyAmount` refactor (ADR-0008) and savings-only scope (ADR-0009) |
| `TransactionRecorded` event + `TransactionRecord` projection | Scaffolded | Per ADR-0005; needs `CurrencyAmount` refactor (ADR-0008) |
| `Features/Accounts/` | Minimal | Endpoint exists |
| `Features/Transactions/` | Minimal | Endpoint exists |
| Auth | Per ADR-0004 | JWT validation in place |
| Wolverine + Marten wiring | Done | Outbox present but unused (no cross-domain events yet) |
| Wolverine.Http handler migration | In progress | Migrating Account/Transaction handlers to Wolverine.Http decider pattern (Slice 1) |

### ADRs accepted (10 total)

ADR-0001 through ADR-0010 — see [`docs/adr/README.md`](./docs/adr/README.md) for the full index.

### Not yet implemented (Phase 1 scope)

- RecurringPayment aggregate (defined in ADR-0005, not built)
- InstallmentPlan aggregate (defined in ADR-0005, not built)
- WishlistItem aggregate (defined in ADR-0005, not built)
- PurchaseOrder aggregate (defined in ADR-0005, not built)
- Budget aggregate (ADR-0006)
- MonthlyReview aggregate + MonthProjection (ADR-0007)
- FX rate service + FxRate projection (ADR-0008)
- Asset aggregate (ADR-0010; Phase 3 implementation but data model from day one)

---

## 2. Architectural refactors required before feature work

These refactors touch existing code and should land first. They are scoped by ADR-0008 and ADR-0009.

### 2.1 Introduce `CurrencyAmount` value object (ADR-0008)

**Why:** Every monetary amount must carry its currency.

**Scope:**

- Add `public sealed record CurrencyAmount(decimal Amount, string Currency)` to `Domain/`.
- Refactor `Account` to single-currency: `Balance: Money`, `Currency: string`. Drop the `Dictionary<string, decimal>` from ADR-0005 (superseded).
- Refactor `TransactionRecorded` event payload: `Amount: decimal` → `Amount: CurrencyAmount`.
- Refactor `TransactionRecord` projection: same.
- Update endpoint request/response DTOs and validators.

**Risk:** Touches the event shape. Mitigated by ADR-0002 (dev-mode versioning flexible until v1 freeze).

### 2.2 Apply savings-only scope (ADR-0009)

**Why:** No checking/credit/cash types. All accounts are savings accounts.

**Scope:**

- Document the constraint in Account endpoint validation.
- Single currency per account (declared at open, immutable).
- No `BalanceOverride` on Account (amended 2026-06-15): the single honesty valve is `MonthlyReview.ActualSavingsOverride` (ADR-0007), applied at month close.
- No type field needed — there's only one type.

### 2.3 Confirm `{ serviceType, externalId }` pattern (cross-cutting)

**Why:** PurchaseOrder line items (ADR-0005) and Assets (ADR-0010) both use this pattern. Decide on the canonical value-object shape now to avoid divergence.

**Scope:**

- Add `public sealed record ExternalReference(string ServiceType, Guid ExternalId)` to `Domain/`.
- Use it consistently wherever cross-service references appear.

---

## 3. Phase 1 feature build order

Each item is a discrete feature slice following the per-feature folder convention from Money AGENTS.md (`Features/<Domain>/<Action>.cs`).

### 3.1 FX rate service (ADR-0008) — *prerequisite for all multi-currency work*

- Quartz cron job (daily, configurable schedule).
- Frankfurter HTTP client (`Features/FxRates/SyncFxRates.cs`).
- `FxRate` projection: `{ Base, Quote, Date, Rate }`.
- Read endpoint: `GET /api/money/fx-rates?base={base}&quote={quote}&date={date}` with forward-fill.
- Failure handling: structured logging, stale-rate alert.

### 3.2 RecurringPayment aggregate (ADR-0005)

- Domain: `Domain/RecurringPayment.cs`, events under `Domain/Events/`.
- Endpoints: create, edit, pause, resume, skip, cancel, list, get-next-N.
- Projection: `RecurringScheduleProjection` for "what's due in month M."
- Currency: amount is `CurrencyAmount` per ADR-0008.

### 3.3 InstallmentPlan aggregate (ADR-0005)

- Domain: `Domain/InstallmentPlan.cs`.
- Endpoints: create, mark-paid, edit-schedule, list-active.
- Projection: outstanding balance per plan; payments scheduled in month M.
- Modeled as RecurringPayment-with-end-date + progress tracking, or its own aggregate — implementation detail, ADR-0005 defers.

### 3.4 WishlistItem aggregate (ADR-0005)

- Domain: `Domain/WishlistItem.cs`.
- Fields: `ServiceType`, `ExternalId` (optional until linked to a domain), `EstimatedCost: Money`, `Notes`, `Status`.
- Endpoints: add, edit, remove, list, **convert-to-PO** (the "plan for this month" action).
- Convert creates a PurchaseOrder in Planned status targeting the specified month.

### 3.5 PurchaseOrder aggregate (ADR-0005)

- Domain: `Domain/PurchaseOrder.cs`.
- Lifecycle: Planned → Ordered → Received (or Cancelled).
- Fields: line items as `ExternalReference[]`, total `CurrencyAmount`, target month, status, transaction links.
- Endpoints: create (from wishlist or direct), advance-status, cancel, list.
- Events emitted at transitions: `PurchaseOrderCreated`, `PurchaseOrderOrdered`, `PurchaseOrderReceived`, `PurchaseOrderCancelled` (per ADR-0005 events table).

### 3.6 Budget aggregate (ADR-0006)

- Domain: `Domain/Budget.cs`.
- Stream key: `budget/{OwnerId}/{Year}/{Month}/{CategoryKey}`.
- Endpoints: set-target, clear-target, list-for-month.
- Projection: actuals aggregation from `TransactionRecord` + settled POs + tag index (tag storage still deferred — see ADR README).

### 3.7 MonthlyReview + MonthProjection (ADR-0007)

- Domain: `Domain/MonthlyReview.cs`.
- Events: `MonthOpened`, `TargetSavingsSet`, `ActualSavingsOverridden`, `MonthClosed`.
- MonthProjection: composed read-model consuming events from all six aggregate families above.
- Endpoints: open-month, set-target, set-actual-override, close-month, get-canvas.
- Close flow: surplus/deficit transaction to savings account at close-day FX rates.
- **Forcing function for:** the Projection strategy deferred decision (inline vs async, snapshots, rebuild). Settle it here.

### 3.8 Transactions polish

- The existing `TransactionRecorded` / `TransactionRecord` scaffolding needs the `CurrencyAmount` refactor and possibly tag linkage.
- Tag storage sub-decision (deferred per ADR README) must land here or earlier.

---

## 4. Phase 3 — Asset aggregate (ADR-0010)

Implementation deferred to Phase 3 per Wallet roadmap, but the data model is locked now. When Phase 3 starts:

- Domain: `Domain/Asset.cs`.
- Events: `AssetTracked`, `AssetImported`, `AssetRevalued`, `AssetListedForSale`, `AssetSold`, `AssetDeleted`.
- Endpoints: import-pre-existing, list-owned, revalue, list-for-sale, mark-sold, delete.
- Projections: net-worth view; gain/loss on sold assets.
- Gateway BFF endpoint `GET /app/v1/inventory` enriches Asset rows with descriptive data from Books/Board Games services.

---

## 5. Sequencing summary

```
Refactors (CurrencyAmount VO, savings-only scope, ExternalReference)
    ↓
3.1 FX rate service                     (prereq for all multi-currency)
    ↓
3.2 RecurringPayment  →  3.3 InstallmentPlan  →  3.4 WishlistItem
    ↓
3.5 PurchaseOrder                       (depends on WishlistItem + ExternalReference)
    ↓
3.6 Budget                              (depends on tags being decided)
    ↓
3.7 MonthlyReview + MonthProjection     (depends on everything above)
    ↓
3.8 Transactions polish
    ↓
[Phase 1 backend complete → Wallet app work begins]
    ↓
Phase 3: Asset aggregate
```

---

## 6. Forcing functions for deferred decisions

| Deferred decision | Forcing function |
|---|---|
| Projection strategy (inline vs async) | 3.7 MonthProjection (consumes 6 streams) |
| Tag storage | 3.6 Budget by tag, or 3.8 transaction filtering |
| Transfer aggregate | Real transfer volume justifies it; for v1 paired transactions with `TransferId` |
| CloudEvents envelope | First cross-domain event published to Kafka (likely AssetSold → Books/BoardGames in Phase 3) |
| Wolverine outbox conventions | Same forcing function as CloudEvents |

---

## 7. Open implementation questions (not ADR-level)

These can be settled during implementation, not before:

- Tag storage mechanism (Marten documents vs side table).
- MonthProjection: inline vs async rebuild vs hybrid.
- FX cron retry/backoff policy specifics.
- Whether to expose raw `FxRate` rows or only via the "rate on date X" query.
- Month-close confirmation flow specifics (frontend concern, but the API shape must support it).
- Whether `ActualSavingsOverride` is one Money or split per currency (current assumption: one, in display currency).
- **User-defined month boundaries** (start/end date set by user, not calendar month). Affects Budget (§3.6) and MonthlyReview (§3.7) stream keys — `Year/Month` may need to become a period identifier. Likely amends ADR-0007. Account and TransactionRecord are not month-scoped.
- **Multiple payments per month** (e.g., salary split into 2 payments). Naturally handled by RecurringPayment recurrence rules — verify at §3.2.

---

*Last updated: 2026-06-15*
