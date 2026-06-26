# Wallet App — Plan

> **Purpose:** This file is the evolving roadmap for the Wallet Flutter app. It captures the full phased vision (Phase 1–5), v1 scope, deferred work, and key design decisions. It is **not** frozen (unlike ADRs). Update freely as work progresses.
>
> **Related:** [Wallet AGENTS.md](./AGENTS.md) for stable conventions; [Money PLAN.md](../../services/money/PLAN.md) for the backend roadmap that drives Wallet work.

---

## 1. App vision

Wallet is a **personal-finance planner**, not a tracker. Its primary job is answering *"what does this month look like financially?"* — not *"what is my current balance?"*

The core mental model is the **savings canvas**:

```
   ┌─────────────────────────────────────┐
   │           March 2026                │
   │                                     │
   │   Projected income      +$4,200     │
   │   Projected spending    -$2,650     │
   │   ─────────────────────────────     │
   │   Planned purchases      -$300      │
   │   ─────────────────────────────     │
   │   Projected savings      +$1,250    │
   │   Your target           +$1,000 ✏️   │
   │   ─────────────────────────────     │
   │   On track by            +$250      │
   │                                     │
   └─────────────────────────────────────┘
```

Two levers the user pulls:
1. **Target savings** — "I want to save \$1,000 this month."
2. **Planned purchases** — Wishlist items moved into "buy this month."

The app shows the consequence: dropping a \$800 lens into March drops projected savings to +\$450, below the \$1,000 target. The user decides; the math is honest.

---

## 2. The three-layer savings model

| Layer | Source | Purpose |
|---|---|---|
| **Target savings** | User-set goal per month | "I want to save \$1,000 this month." |
| **Projected savings** | Computed: `income − spending − planned_purchases` | "Based on what I've planned, I'm on track for \$1,250." |
| **Actual savings (override)** | User-entered real number | "In reality I saved \$1,180 — accounts for the coffees I didn't log." |

The actual-override is the **honesty valve**: it lets the planner tolerate gaps in transaction logging without forcing the user to itemize every coffee.

- Power-user mode: log everything → projected converges with actual → override stays empty.
- Big-picture mode: log only big things → projected drifts → user enters actual at month-end.

Both styles work without the app shaming either. Transactions are **frequency-up-to-user**: a user can log every coffee or log nothing and rely on the override.

---

## 3. Design principles

1. **Planner, not tracker.** Home is the savings canvas. Transactions are demoted to optional actuals that refine projections.
2. **Multi-currency from day one.** Money (the value object) is `Money { Amount, Currency }`. The user has multiple savings accounts in different currencies. The canvas aggregates to a display currency; line items render as "original + converted inline" (€80 (~\$86)).
3. **Honesty valves everywhere.** Target savings, actual savings override, savings account balance override, asset estimated value — user-truth beats computed-truth wherever a real number matters.
4. **No false precision.** Don't display a balance the user can't verify. Don't imply the app knows what it doesn't. The actual-override is the explicit acknowledgment of this.
5. **Solo-first, family-aware.** v1 is single-user. The data model carries `OwnerId` everywhere so adding family UX later is a UI concern, not a migration.

---

## 4. Phase 1 — Solo planner (v1 scope)

### Platforms

Android, Web, Windows, Linux. (macOS/iOS technically free; not prioritized.)

### Screens

| Screen | Job | Backend (Money) |
|---|---|---|
| **Month overview (Home)** | Savings canvas: target / projected / actual; planned purchases summary; recent activity preview | `MonthProjection` (ADR-0007) |
| **Recurring editor** | Engine of projections: known income, bills, subscriptions, installments | `RecurringPayment`, `InstallmentPlan` (ADR-0005) |
| **Wishlist + planned purchases** | What you want vs. what fits this month; convert-to-PO action | `WishlistItem`, `PurchaseOrder` (ADR-0005) |
| **Transactions log** | Optional actuals — record what really happened, used to refine projections | `TransactionRecorded` (ADR-0005) |
| **Light budgets** | Per-category spend targets; actuals plugged in when logged | `Budget` (ADR-0006) |
| **Savings accounts** | List of accounts with balances (override-enabled); create/edit | `Account` (ADR-0005, ADR-0009) |

### Out-of-scope for v1

- Domain-linked purchases (Phase 2: Books, Board Games deep-linking)
- Inventory & net worth (Phase 3: Asset aggregate)
- Family UX (Phase 4)
- Long-term analytics, year review, reports (Phase 5)
- Voice/photo receipt capture (depends on Document Processing service)
- Bank/SMS auto-import (out of scope indefinitely unless a forcing function arrives)
- Savings goals (named allocation pools) — Wishlist already serves this purpose

### Backend prerequisite

v1 requires the full Phase 1 Money backend (see [Money PLAN.md](../../services/money/PLAN.md) §3). Sequencing is **backend-first**: Money features land, then Wallet UI is built against the real API. No mock/stub parallel track in v1.

### Auth & first-run (Money [ADR-0014](../../services/money/docs/adr/0014-auth-session-lifetimes-and-passkeys.md))

- **First-run onboarding** *(built)* — "Set up your first month": first savings account + display currency + configurable month start day (Money ADR-0013). The router gates on `UserPreferences.DisplayCurrency` being null; responsive (two-column wide / stacked phone) with a live "savings canvas" preview.
- **Per-platform session scope** *(built)* — requests `offline_access` on native/desktop only, omits on web (`AuthConfig.scopes` gated on `kIsWeb`). Native gets a long offline session (idle 60d / max 180d); web a short online session (idle 30m / max 24h). One realm config, split by scope.
- **Biometric app-lock** *(built, native only)* — via `local_auth`: required on cold start, re-lock after ~5 min in background, user-configurable (default on); optional toggle shown in onboarding only where the device supports it. The lock screen always offers **"Use password"** and **"Log out / sign in as a different account."** No-op on web. On-device biometric prompt pending manual verification.
- **Passkey login** *(built, web-verified)* — WebAuthn/FIDO2 as the preferred Keycloak login method, **password always available as fallback** (bootstrap + recovery). On Keycloak 26.4+ enabling `webAuthnPolicyPasswordlessPasskeysEnabled` auto-integrates passkeys (conditional + modal UI) into the default browser flow — no custom flow JSON needed. The custom login theme's `template.ftl` must include the `rfc4648` import map the base theme provides, or the WebAuthn ES modules fail silently ("Failed to resolve module specifier rfc4648") and `navigator.credentials.create/get` never runs. Verified end-to-end via a Chrome virtual authenticator: enrollment (alice is seeded with the `webauthn-register-passwordless` required action → registers a passkey, password fallback retained) and passkey-only login (conditional-UI autofill → auth code, no password).

#### Auth — remaining / revisit later

Auth is **dev-complete and verified** as of 2026-06-26. None of the below are blockers; they are on-device checks that need real hardware, one optional UX, and deployment-phase hardening. Pick up here when able.

- [ ] **On-device biometric app-lock prompt** *(manual verify)* — the `local_auth` flow is proven as a web no-op; the real fingerprint/face prompt on a native device is untested.
- [ ] **Native / platform passkey authenticator** *(manual verify)* — passkey enrollment + passwordless login verified on web with a virtual authenticator; a real device/platform authenticator is untested.
- [ ] **In-app passkey enrollment deep-link** *(optional UX)* — the enrollment *mechanism* works (Keycloak `webauthn-register-passwordless` required action / Account Console); surface it from Wallet settings as the in-app opt-in ("A+B").
- [ ] **Prod hardening** *(deployment phase)* — real WebAuthn RP ID (passkeys currently assume `localhost`); Postgres-backed Keycloak DB (dev uses an H2 data volume); real secrets (not `devsecret` / `admin`/`admin`); brute-force protection (currently `bruteForceProtected: false` in the dev realm).

---

## 5. Phase 2 — Domain-linked purchases

When Books and Board Games services come online:

- Wishlist and PO flows gain the `{ serviceType, externalId }` link to real domain objects.
- Categories auto-populate from domains (`books`, `board-games`).
- Wallet deep-links to the relevant domain app (or shows an inline preview via Gateway BFF composition).
- No new Wallet feature modules per se — the existing wishlist/PO UI becomes "richer" when a domain is linked.

The Phase 1 data model already supports this via `ExternalReference`; Phase 2 is UI work, not schema migration.

---

## 6. Phase 3 — Inventory & net worth

- **Money Asset aggregate** (ADR-0010) ships. Two ingestion paths:
  - *Tracked:* PO advances to Received → `AssetTracked` event.
  - *Pre-existing import:* user adds directly with `AcquiredDate`, `AcquiredCost`, `CurrentEstimatedValue`. Bypasses MonthlyReview entirely.
- New Wallet screen: **Inventory** — list of owned Assets with values; edit `CurrentEstimatedValue`; mark for sale; record sale.
- New Wallet screen: **Net worth** — savings balances + asset values − outstanding installment balances, all in display currency.
- Gateway BFF endpoint `GET /app/v1/inventory` enriches Asset rows with descriptive data from Books/Board Games (title, cover) for display. Math never depends on enrichment.
- **Bought-for vs sold-for stat:** computed on sold Assets — `SoldFor − AcquiredCost`, both converted via ADR-0008.

---

## 7. Phase 4 — Family / multi-user

- Shared savings accounts with permissions.
- His / hers / ours tagging on transactions and POs.
- Per-user budgets.
- Family-level net worth view.
- The data model already carries `OwnerId` (ADR-0004); Phase 4 is primarily UI + permission enforcement, not schema migration.

---

## 8. Phase 5 — Long-term analytics

- Year+ trends: savings rate, category spend, net-worth trajectory.
- "Should I buy this over time?" advisor: project impact of a deferred purchase on savings trajectory.
- Multi-month recurring review.
- All read-only views over existing data — no new aggregates expected.

---

## 9. Cross-cutting decisions (already settled)

| Topic | Decision | Source |
|---|---|---|
| App structure | Money-only app now, others later (no unified LifeOS shell) | User decision |
| Platforms | Android, Web, Windows, Linux | User decision |
| State management | Riverpod | User decision |
| API client | OpenAPI codegen (dart-dio) from Money's `/openapi/v1.json` | User decision |
| BFF routes | Gateway `/app/v1/*` (renamed from `/mobile/v1/*`) | Gateway AGENTS.md |
| Offline model | Read models + pending-operations outbox in drift. No client-side event sourcing. | User decision |
| Family stance v1 | Solo only; data model family-aware | User decision |
| Categories | Dual-track: domain (`serviceType+externalId`) + free-text tags. No fixed category list. | User decision |
| Budgets v1 | Light, monthly, no envelopes, no rollover | Money ADR-0006 |
| Savings model | Three-layer: target / projected / actual-override | Money ADR-0007 |
| Multi-currency | In v1 with FX service (Frankfurter) | Money ADR-0008 |
| Accounts | Savings only; one currency per account | Money ADR-0009 |
| Inventory architecture | Asset aggregate inside Money, financial fields only | Money ADR-0010 |
| Income pattern | Stable + resale (later); planner accommodates variable | User decision |
| Subscriptions | Modeled as tagged `RecurringPayment`; not a distinct concept | User decision |
| Auth session & login UX | Per-platform token lifetimes; passkey-preferred + password fallback; native biometric app-lock; short web session | Money ADR-0014 |

---

## 10. Open implementation questions

These can be settled during implementation, not before:

- FX display formatting edge cases (how many decimals, when to suppress the original).
- Whether month-close auto-creates the savings transfer transaction or requires explicit user confirmation in the close flow.
- Tag UI (autocomplete, recent tags, multi-tag on one transaction).
- Wishlist → PO conversion: drag-and-drop vs. button-driven; whether to allow partial (split a wishlist item across months).
- Whether `ActualSavingsOverride` accepts one Money (display currency) or per-currency breakdowns.
- Savings-account creation flow specifics (default currency, opening balance source).
- Web-specific UX (responsive layout, mobile-vs-desktop affordances).

---

## 11. What Wallet will NOT do (anti-scope)

- ❌ **Bank integration.** No Plaid, no SMS parsing. All data is user-entered or server-projected.
- ❌ **Tax handling.** No tax categorization, no export to tax software. Out of scope indefinitely.
- ❌ **Investment tracking.** Stocks, crypto, etc. are not in scope. Money is for cash savings, planned spending, and physical/digital asset resale values only.
- ❌ **Credit score / financial product recommendations.** Not a fintech app.
- ❌ **Budget enforcement / spend-blocking.** Budgets are advisory; the planner shows over-spend visually but never prevents it.
- ❌ **Multi-user real-time collaboration.** Phase 4 is sequential family UX (his/hers/ours tagging), not concurrent edit.

---

*Last updated: 2026-06-15*
