# ADR-0006: The acquisition-to-ownership flow and a revised navigation shell

## Status

Accepted

Date: 2026-07-08

**Amends:**

- [ADR-0002](./0002-navigation-and-information-architecture.md) — the **destination set** and **Home's content**. Accounts is dropped as a bottom-tab and folds into Home; Wishlist is confirmed as its own destination; Home's thesis widens from "current-period cockpit" to **current standing** (this month's flow + period-independent stocks). Reverses ADR-0002's plan to grow a **"Wishlist → Inventory / Net worth"** lens and its "pinned-rates card under Accounts" (Accounts is no longer a tab).

**Relates to:** [ADR-0005](./0005-plan-destination-and-planning-views.md) (Plan stays a destination), [Money ADR-0030](../../../../services/money/docs/adr/0030-external-domain-linking-and-wishlist-creation.md) / [ADR-0031](../../../../services/money/docs/adr/0031-order-aggregate-ancillary-costs-and-receipt.md) / [ADR-0032](../../../../services/money/docs/adr/0032-asset-lifecycle-event-sourced-ownership.md) (the backend this UI sits on — external linking, the Order aggregate, the Asset lifecycle), [Money ADR-0010](../../../../services/money/docs/adr/0010-asset-aggregate.md) / [ADR-0022](../../../../services/money/docs/adr/0022-wishlist-items-packages-and-derived-status.md) (assets, wishlist).

## Context

This session designed the backend for the full **want → order → own** flow (Money ADR-0030 external-domain linking, ADR-0031 the Order aggregate, ADR-0032 the Asset lifecycle). That surfaced **four UI surfaces** needing homes:

1. the **wishlist** (where wants land),
2. **orders** (assemble + pay + track + receive a purchase),
3. **owned collection** (loaned-to-a-friend, condition, played),
4. **owned value / net worth**.

Two decisions from the backend design reshaped where these live:

- **The net-worth-effect boundary** (Money ADR-0032). Marking a board game *loaned to a friend* moves no money — the item is still owned, net worth unchanged. So possession states are **not** a finance-app concern; they belong to the app that owns the *thing*. Money holds only value-moving events. This kills ADR-0002's idea of a Wallet "Inventory" lens.
- **Net worth is a derived readout** — something you *see*, not *operate*. It belongs with other stats, not bolted onto an operational tab.

Separately, the navigation had drifted and needed reconciling: ADR-0002 set `Home · Activity · Accounts · Wishlist`; ADR-0005 reinstated **Plan**; the running app shell shows `Home · Plan · Activity · Accounts` with no Wishlist. Adding a Wishlist destination (and a future Stats one) while keeping Accounts would overflow a phone bottom bar.

Forces at play:

- **Orders are period-independent.** Money ADR-0031 makes the Order its own cross-period stream with a **fuzzy-by-default ETA** (a month, not a day, for international post). A package due tomorrow must not be hidden because a new accounting period opens tomorrow.
- **Account management is low-frequency.** You set up savings pots once and then mostly glance at balances; create/rename/transfer is rare. Low-frequency management earns a **sub-surface, not a permanent tab.**
- Savings pots are **already wired into Home's month** (close-time allocation, Money ADR-0021; extra/early payments dipping savings) — so they belong to Home's world, not a bolt-on.
- Nav real estate: a phone bottom bar wants **≤ 5**; the domain apps (Board Games, Books) that would own collection **do not exist yet**.

## Decision

### The four surfaces, placed

- **Wishlist → its own destination.** Confirms the slot ADR-0002 gave Wishlist and ADR-0005 reopened. **Provisional**, pending the app-wide feature-map review.
- **Orders → Home.** Created via a **Home FAB verb** ("Buy" / "New order") and from the Wishlist ("Order these wants"); no dedicated create screen. Open orders show on Home as a period-decoupled **"Arriving" strip** — a rolling window (e.g. next 30 days), keyed on **ETA, not period**, expandable/pageable. Cancel / edit / **Mark received** (the receipt confirmation window, Money ADR-0031) happen from that strip / its expanded list. ETA is **fuzzy (month) by default, precise (date) when known**.
- **Owned collection → the owning domain apps** (Board Games, Books), **not Wallet.** Loaned-to-whom, condition, played — all zero-net-worth-effect possession states — live with the thing. The **net-worth-effect test** is the boundary.
- **Owned value / net worth → a future Stats destination.** Deferred (it depends on unbuilt projection/asset data). This **replaces** ADR-0002's "Wishlist grows an Inventory/Net-worth lens."

### Accounts folds into Home

Drop the **Accounts** bottom-tab. Home shows the savings pots as a **glance** (the currency-pool header). A **"Manage"** affordance opens the account surface as a **pushed screen** — the full former-Accounts content: account list, create / rename / archive, deposit / withdraw, transfer, reconcile, and per-account movement history. **Nothing is lost** — only the entry point changes (tab → Home affordance). Management stays *behind* the affordance so Home remains a summary.

### Home's thesis widens to "current standing"

Home is this month's **flow** (period-switched) **plus current stocks that are period-independent**: the **savings pots** and the **arriving-orders** strip. The period switcher governs only the flow section; the stocks are always-current. Two deliberate period-decoupled elements, stated so they read as intentional rather than as leaks.

### The revised shell

Near-term the authenticated shell is:

> **Home · Plan · Wishlist · Activity**

Accounts is folded into Home; **Stats** arrives later, when net worth + projections are real. This amends ADR-0002's `Home · Activity · Accounts · Wishlist` and reconciles the post-ADR-0005 drift.

### Provisional — pending the feature-map review

The **Wishlist-as-its-own-tab** and the **Stats** destination are provisional placements, to be confirmed by the app-wide feature-map / IA review; the bar may compress further there (e.g. Stats starting as a Home section, Wishlist pairing with Plan).

## Consequences

Positive:

- Every acquisition surface has a home grounded in a principle — the net-worth-effect boundary (collection → domain apps), low-frequency-management → sub-surface (Accounts → Home), derived-readout → Stats (net worth).
- Arriving-orders on Home is period-correct — a package due tomorrow is never hidden by a period rollover, because the Order is its own stream.
- Dropping Accounts as a tab keeps the near-term bar at four with room for Wishlist; Wallet stays financial while the *thing* stays with its domain app.

Negative:

- Reverses ADR-0002's "Wishlist → Inventory/Net worth" lens and its pinned-rates-under-Accounts placement. Build changes: router drops the Accounts branch and adds Wishlist; Home gains a pots-glance, an arriving strip, and the Manage surface.
- Home accumulates period-independent elements — a cockpit-bloat risk, mitigated by keeping management behind affordances (pots glance → Manage sheet; arriving glance → expand).
- Net worth has **no home** until Stats exists. Accepted: the primary user is not net-worth-driven, and the underlying data is unbuilt anyway.

Neutral:

- Wishlist-as-a-tab and Stats are provisional pending the feature-map review.
- Owned collection depends on domain apps that do not yet exist; until they ship, a received asset has a **financial record** in Money but **no collection UI** (loaning etc. is deferred alongside those apps).

## Alternatives Considered

1. **Keep Accounts as a bottom-tab.** Rejected: account management is low-frequency; a permanent tab overweights it and, with Wishlist (and later Stats) incoming, overflows the bar. Folding into Home loses nothing but the tab.
2. **Put net worth / owned-value on Accounts (a balance-sheet tab).** Rejected: net worth is a derived readout (a *see*, not a *do*); it belongs with stats, and folding it onto Accounts would block Accounts on unbuilt projection data.
3. **Keep collection (loan / condition) in Wallet.** Rejected: it moves no money (net-worth-effect test); recording "loaned to a friend" in a finance app is the wrong home. It belongs to the owning domain app.
4. **A dedicated "Things" / possession tab (Wishlist + Orders + Owned).** Rejected: once collection left for the domain apps and value left for Stats, the tab's legs dissolved — Orders fit Home's arriving strip, Wishlist stands alone.
5. **Orders as their own tab.** Rejected: in-flight orders are a current-standing glance that fits Home; creation is a FAB verb. A separate tab is unwarranted.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
