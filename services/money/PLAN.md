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

### ADRs accepted (27 total)

ADR-0001 through ADR-0027 — see [`docs/adr/README.md`](./docs/adr/README.md) for the full index. ADRs 0016–0023 (the AccountingPeriod / period-centric / line-items / close / wishlist / active-month cluster, 2026-06-26/27) substantially reshape the aggregate model; ADRs 0024–0027 (2026-06-28) add the managed category model, period-centric budget, actuals honesty (`actual = Σ flows`), and early payment. §3 is updated to reflect them.

### Not yet implemented (Phase 1 scope)

- UserPreferences document (ADR-0013; display currency + configurable month start day — see §3.0)
- AccountingPeriod aggregate + MonthProjection (ADR-0016, renamed from MonthlyReview; holds lifecycle + flow ledger + planned purchases)
- ~~RecurringPayment aggregate (ADR-0017; Live + Materialized modes; collapses InstallmentPlan)~~ — **Part A DONE (2026-07-01)**: rules/generator/aggregate/endpoints. Part B (period integration: confirm/skip + status) pending. See §3.2
- WishlistItem + Package documents + WishlistItemStatus projection (ADR-0022; non-event-sourced)
- Planned-purchase events on AccountingPeriod (ADR-0018/0019)
- Budget aggregate (ADR-0006)
- ~~FX rate service + FxRate document (ADR-0015)~~ — **backend DONE (2026-07-01)**, see §3.1 (client cache/Rates view deferred)
- Asset aggregate (ADR-0010; Phase 3, ingestion path amended by ADR-0018)
- ~~PurchaseOrder aggregate~~ — **dropped** per ADR-0018 (planned purchases live on AccountingPeriod)
- ~~InstallmentPlan aggregate~~ — **collapsed** into RecurringPayment per ADR-0017

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
- No `BalanceOverride` on Account (amended 2026-06-15): account balances are movement-derived (`SavingsMovementRecorded`, ADR-0026). The period-level honesty valve is the `UnaccountedFlowRecorded` gap entry (ADR-0026; supersedes the removed `ActualSavingsOverride`), so **actual = Σ flows**.
- No type field needed — there's only one type.

### 2.3 Confirm `{ serviceType, externalId }` pattern (cross-cutting)

**Why:** PurchaseOrder line items (ADR-0005) and Assets (ADR-0010) both use this pattern. Decide on the canonical value-object shape now to avoid divergence.

**Scope:**

- Add `public sealed record ExternalReference(string ServiceType, Guid ExternalId)` to `Domain/`.
- Use it consistently wherever cross-service references appear.

---

## 3. Phase 1 feature build order

Each item is a discrete feature slice following the per-feature folder convention from Money AGENTS.md (`Features/<Domain>/<Action>.cs`).

### 3.0 UserPreferences (ADR-0013) — *foundational config; precedes period-scoped and FX work*

- Storage: a Marten **document** `UserPreferences` keyed by `OwnerId` (not event-sourced — see ADR-0013). Fields: `MonthStartDay` (int, 1–31, last-day clamped, default 1), `DisplayCurrency` (string?, ISO 4217, null until onboarding sets it).
- Feature folder `Features/UserPreferences/`: `GET /api/money/preferences` (returns current or defaults), `PUT .../display-currency`, `PUT .../month-start-day` (409 if any `MonthlyReview` is `Closed`).
- Period helper: `anchor(Y, M) = min(MonthStartDay, daysInMonth(Y, M))`; period `(Y, M) = [anchor(Y, M), anchor(next))`. This helper is consumed by Budget (§3.6) and MonthlyReview/MonthProjection (§3.7) bucketing.
- Why first: §3.1 FX syncs "the user's display currency plus account currencies," and the period helper is a prerequisite for §3.6/§3.7. `DisplayCurrency` is the canvas/budget aggregation currency throughout.

### 3.1 FX rate service (ADR-0015, supersedes ADR-0008 FX section) — *prerequisite for all multi-currency work* — **backend DONE (2026-07-01)**

Implemented backend (frontend/client cache + Rates view deferred, ADR-0015):

- **`FxRate` document** (`Domain/Fx/FxRate.cs`) — Marten document, not events: `{ Id, Base, Quote, Date, Rate, Source, RetrievedAt }`, deterministic id `Base:Quote:Date:Source` (idempotent re-fetch). `FxSource` constants (`belarusbank` | `frankfurter`).
- **Two sources** (`Fx/IFxRateSource.cs`): `BelarusbankRateSource` (`kurs_cards`, SELL side, direct foreign→BYN pairs, defensive regex parse, per-unit scale for RUB-per-100) + `FrankfurterRateSource` (`latest?base=&symbols=`, fallback). Sources tolerate outages (return empty, never throw).
- **`FxRateFetchService`** — plain `BackgroundService` + `PeriodicTimer`, **hourly** (no Quartz, per ADR-0015). Currency set = config ∪ display currencies ∪ account currencies; upserts both sources; stale-rate warning; `Fx:Enabled` gate (off in tests). Immediate fetch on startup.
- **Read endpoints**: `GET /api/money/fx-rates?base=&quote=&date=` (forward-fill + source precedence + inverse-pair reciprocation; 404 when uncovered) and `GET /api/money/fx-rates/latest` (one row per pair+source, uncollapsed — feeds the future client cache + Settings). `FxRateResolver` holds the pure forward-fill/precedence logic.
- **Config** (`Fx` section) + `FxOptions`: interval, currency list, pivot (BYN), URLs, staleness, and **`SourcePriority`** — an ordered list driving read precedence, the hook a future per-user *source Settings* feature (priority + on/off toggles) plugs into. All sources are always stored independently.
- Tests: `BelarusbankRateSource.Parse` unit tests, `FxRateResolver` unit tests, endpoint integration tests (18 total, green).

**Deferred (not blocking):** cross-currency **triangulation** (reads answer stored pairs + inverse only); the client 15-min rate cache + in-app **Rates view** (frontend); `DefaultSpendingCurrency` on `UserPreferences` (ADR-0015 amends ADR-0013 — a separate preferences change); Belarusbank **BUY** side (foreign-currency income). Confirm the Belarusbank per-unit scales against live payloads (`FxOptions.BelarusbankUnitScale`).

### 3.2 RecurringPayment aggregate (ADR-0017, as amended by ADR-0019/0020) — **Part A DONE (2026-07-01)**

Built (Part A — definition, schedule, occurrence *computation*; period integration is Part B):

- **Recurrence model** (`Domain/Recurring/`): sealed `RecurrenceRule` hierarchy (Daily/Weekly/Monthly/Yearly) + `RecurrenceEnd` (Never/OnDate/AfterCount) + `MonthDayAnchor` (day-of-month clamped / last-day) + `AnnualDate`, serialized as a `kind`-discriminated STJ union (`[JsonPolymorphic]`) mirrored by the Dart client. `RecurrenceGenerator` — pure, exhaustive-switch occurrence computation (every-N-days, bi-weekly, quarterly, clamping, count/date end, forward `Take(n)`), heavily unit-tested.
- **Aggregate** (`Domain/RecurringPayment.cs`) + events (`RecurringPaymentCreated`/`RuleChanged`/`ScheduleLineAdded`/`Edited`/`Removed`/`RecurringPaymentEdited`/`RecurringPaymentCancelled`), inline snapshot. **Two modes**: Live (rule + `EstimateLines`) / Materialized (`ScheduleLine` list, each with a `list<Line>` breakdown, ADR-0019). Status Active→Cancelled (terminal).
- **Endpoints** (`Features/Recurring/`): create (both modes), get, list, edit-rule (Live, forward-only), edit-header, add/edit/remove schedule line (Materialized), cancel, and get-occurrences (computed window). Owner-scoped; lifecycle/mode guards → 404/409; client-assigned id idempotency (ADR-0003).
- Tests: generator + JSON round-trip + aggregate + endpoint integration (36 total, green).

**Serializer note:** Marten switched to System.Text.Json (`Program.cs`) so the rule union round-trips identically in the event store and the API contract. **`AllowOutOfOrderMetadataProperties` is required** — STJ writes `kind` first but Postgres jsonb reorders keys, so the polymorphic reader would otherwise fail on read. Pre-prod, no migration; a local dev money-db with pre-switch (Newtonsoft) events must be reset (drop the `money-db` volume).

**Part B (next) — AccountingPeriod integration:** `confirm-occurrence` (→ `FlowRecorded` with `{recurringId, occurrenceRef}` back-ref) and `skip-occurrence` (→ `OccurrenceSkipped`); the per-occurrence **status** (projected/paid/skipped) join in get-occurrences and a `RecurringScheduleProjection` for "what's due in period P." The "unconfirmed only" guard on Materialized line edit/remove also lands here (needs the period join).

**Part C (later) — needs planned-purchases (ADR-0018) first:** carry-make-up (ADR-0020) and early-payment (ADR-0027).

### 3.3 Wishlist items, packages, and derived status (ADR-0022)

- Non-event-sourced documents: `WishlistItem` (one per item) + `Package` (grouping + name). **Not aggregates** — ADR-0005's event-sourced WishlistItem is superseded.
- `WishlistItemStatus` projection: incrementally-maintained per-item status (`NotPlanned`/`Planned`/`Ordered`/`Received`) derived from AccountingPeriod events via `Line.WishlistItemId` joins.
- Endpoints: CRUD for items and packages.
- Fine-grained items grouped by package (each addon is its own item); package status is a derived rollup.

### 3.4 Planned purchases on AccountingPeriod (ADR-0018 + ADR-0019)

- Planned spending lives on the period stream as events: `PlannedPurchaseAdded`/`Cancelled`/`Edited`, each carrying `list<Line>`.
- The PurchaseOrder aggregate (ADR-0005) is **dropped** for v1 — not built. Planning is period-centric.
- Conversion to paid = a `FlowRecorded` (ADR-0016) with a `{ PlannedEntryId }` back-ref; actual lines may differ from the plan.
- Carry-at-close / carry-make-up writes a `PlannedPurchaseAdded` to the next period with an `Origin` soft-ref.
- Fulfillment/asset tracking (Phase 3): a paid entry marked received creates an Asset directly (amends ADR-0010; no PO).

### 3.5 ~~PurchaseOrder aggregate~~ (dropped per ADR-0018)

- The PurchaseOrder aggregate is **not built in v1**. Its planning job moved to AccountingPeriod (§3.4); its fulfillment job moved to the Asset aggregate (Phase 3, §4). This slice is retained only to record the removal.

### 3.6 Budget (ADR-0025; supersedes ADR-0006; categories per ADR-0024)

- Marten **document** keyed per (owner, period, `CategoryId`) — not an aggregate (supersedes 0006). `Domain/` holds no Budget aggregate; it is a document.
- Endpoints: set-target, clear-target, list-for-period.
- Projection: `BudgetActuals` — actuals aggregation from `FlowRecorded` **lines** grouped by per-line **`CategoryId`** (system or user category, ADR-0024), signed sum (spending +, refunds −), event-time FX to display currency. `remaining = target − spent` computed at read time. Per-period; client "copy last month" bulk; no templates.

### 3.7 AccountingPeriod + MonthProjection (ADR-0007, renamed/reframed by ADR-0016; close by ADR-0021; active-month by ADR-0023)

- Domain: `Domain/AccountingPeriod.cs` (renamed from MonthlyReview per ADR-0016). One stream `period/{OwnerId}/{Year}/{Month}` holds lifecycle + the flow ledger (`FlowRecorded`/`FlowReverted`, each `list<Line>` per ADR-0019) + planned purchases (`PlannedPurchaseAdded`/`Cancelled`/`Edited`, ADR-0018).
- Lifecycle events: `MonthOpened`, `TargetSavingsSet`, `ActualSavingsOverridden`, `MonthClosed`. Once closed, the stream rejects all events (lifecycle + flow + planned).
- MonthProjection: composed read-model sourcing planned purchases + actuals from period events (no cross-stream PO join).
- Endpoints: open-period, set-target, set-actual-override, close-period, get-canvas, add-planned-purchase, cancel/edit-planned-purchase, record-flow.
- Close flow (ADR-0021): surplus/deficit **allocated across one or more savings accounts** (user-truth, not validated); unpaid-item dispositions (cancel/defer/skip/re-date/carry-make-up) appended in the close transaction.
- Active-month (ADR-0023): multiple periods may be open; future periods accept **planning operations only**; actuals route by date; the active period (current month) is the UI focus.
- **Forcing function for:** the Projection strategy deferred decision (inline vs async, snapshots, rebuild). Settle it here.

### 3.8 Transactions polish

- The existing `TransactionRecorded` scaffolding is refactored along two paths: everyday actuals → `FlowRecorded` on AccountingPeriod (ADR-0016/0019); account-side savings movements → `SavingsMovementRecorded` on Account (ADR-0026). The generic `TransactionRecorded` is superseded.
- Categorization uses a managed `CategoryId` per line (ADR-0024) — there are **no tags** (the tag-storage sub-decision is moot).
- The honesty valve is `UnaccountedFlowRecorded` (the gap entry); `ActualSavingsOverride` is removed (ADR-0026).

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
3.0 UserPreferences                     (display currency + period anchor; prereq for FX and period-scoped work)
    ↓
3.1 FX rate service                     (prereq for all multi-currency)
    ↓
3.2 RecurringPayment (ADR-0017; incl. installments via Materialized)
    ↓
3.3 Wishlist items + packages (ADR-0022)  →  3.4 Planned purchases on AccountingPeriod (ADR-0018/0019)
    ↓
3.6 Budget                              (depends on per-line Category / tag storage)
    ↓
3.7 AccountingPeriod + MonthProjection  (depends on everything above; close flow ADR-0021)
    ↓
3.8 Transactions polish
    ↓
[Phase 1 backend complete → Wallet app work begins]
    ↓
Phase 3: Asset aggregate (paid-entry → Asset per ADR-0018)
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
- ~~`ActualSavingsOverride` vs allocations~~ — **Resolved by ADR-0026.** The override is removed; **actual = Σ flows** (incl. an `UnaccountedFlowRecorded` gap entry); close distributes Σ flows across accounts (`Σ allocations = actual`); **dipping into savings = close-time aggregate** (no mid-month per-purchase withdrawals in v1); **variance = actual − projected** (computed in MonthProjection).
- ~~**User-defined month boundaries**~~ — **Resolved by ADR-0013.** Configurable `MonthStartDay` (1–31, last-day clamped) lives on the new `UserPreferences` document; `(Year, Month)` is generalized to a start-anchored period (calendar months are the `MonthStartDay = 1` degeneracy). Amends the period-keying of ADR-0006 (§3.6) and ADR-0007 (§3.7); key shape unchanged. Account and TransactionRecord remain non-period-scoped. Build slice: §3.0.
- **Multiple payments per month** (e.g., salary split into 2 payments). Naturally handled by RecurringPayment recurrence rules — verify at §3.2.

---

## 8. Production schema migration (deferred — do properly at CI/CD)

`AutoCreate` is now environment-gated in `Program.cs`: `All` in Development (startup creates/updates the schema for fast iteration), `None` everywhere else (the app never mutates the schema at runtime and fails fast if it is missing). This is the correct *target* setting, but the operational machinery to apply migrations is **not yet wired** — that work lands with CI/CD.

When CI/CD is set up, do it properly:

1. **Enable the JasperFx command line** — change the entry point to `return await app.RunJasperFxCommands(args);` so the same executable can run admin commands.
2. **Pre-deploy migration step** — run `dotnet run -- resources setup` as a dedicated job / init-container (never at app start). It covers *all three* schema owners in one pass: Marten document/event tables, Marten projection tables, and the Wolverine durability/outbox tables (`wolverine` schema). Use a DDL-privileged DB role for this step; run the app itself under a least-privilege (DML-only) role.
3. **CI gate** — `dotnet run -- resources check` (and/or `db-assert`) to fail the pipeline on schema drift *before* deploy.
4. **AOT codegen** — `dotnet run -- codegen write` at build time plus `TypeLoadMode.Static` in production, so Wolverine/Marten stop compiling handler code at runtime (currently logs "code generation mode is Dynamic").
5. **SQL review (optional, stricter)** — `dotnet run -- db-patch` / `db-dump` to produce reviewable DDL fed through Flyway/DbUp instead of tool-applied `resources setup`.

Local dev and integration tests are unaffected: both run as Development and auto-create against the Aspire Postgres / Testcontainers instance.

---

## 9. Social login: "Log in with Google" (deferred — not started)

Add Google as an upstream identity provider that Keycloak **brokers**. Free (plain Google OAuth 2.0, no per-user cost; only a consent-screen verification step for prod external users). Deliberately not built yet.

**Why it's low-impact:** Keycloak still issues the same `lifeos`-realm token regardless of how the user authenticated, so **Money and the integration tests need no changes** (`iss`/`aud`/`sub` semantics are unchanged; `sub` is the brokered Keycloak user id). The "Log in with Google" button renders automatically once the IdP is enabled. Google login is interactive-only, so it stays a manual/e2e concern — not covered by the xUnit suite.

When we pick it up:

1. **Google Cloud Console** — create an OAuth 2.0 Web client; set the authorized redirect URI to the Keycloak broker endpoint `http://localhost:8080/realms/lifeos/broker/google/endpoint` (relies on the fixed port 8080, ADR-0004). Separate client per environment (prod uses the real domain).
2. **Realm IdP** — add an `identityProviders` entry (`alias: google`, `providerId: google`, `trustEmail: true`, `syncMode: IMPORT`) to `keycloak/lifeos-realm.json`, with `clientId`/`clientSecret` as `${GOOGLE_CLIENT_ID}` / `${GOOGLE_CLIENT_SECRET}` placeholders (Keycloak substitutes from env on realm import — keeps secrets out of git).
3. **Secret wiring (Aspire)** — `AddParameter("google-client-id")` + `AddParameter("google-client-secret", secret: true)`, passed to the Keycloak resource via `.WithEnvironment(...)`; real values set with `dotnet user-secrets` on the AppHost. Prod: secrets from the vault/secret store, IdP managed via IaC (per §8 / ADR-0012 stance).

Do **not** use Google Cloud Identity Platform / Firebase Auth (paid, managed) — Keycloak is already the auth server; Google is only an upstream OAuth provider.

---

*Last updated: 2026-06-28*
