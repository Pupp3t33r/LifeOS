# ADR-0024: Category model (managed system + user categories)

## Status

Accepted

Date: 2026-06-28

**Supersedes:**

- The **"dual-track: domain + free-text tags / no fixed category list"** stance recorded in [`apps/wallet/PLAN.md`](../../../../apps/wallet/PLAN.md) §9 ("Categories: Dual-track…"), [`apps/wallet/AGENTS.md`](../../../../apps/wallet/AGENTS.md) ("Categorization"), and [`AGENTS.md`](./../../AGENTS.md) ("Categorization (dual-track, per-line)"). The free-text tag concept is removed entirely; LifeOS now has a **managed category list** (system + user), one category per line.

**Amends:**

- [ADR-0019](./0019-universal-line-items.md) — the `Line.Category` discriminated union (`ExternalReference | Tag`) is removed. `Line` now carries `CategoryId: Guid?` (the single budgeting category) **and** a separate `ExternalRef: ExternalReference?` (a direct link to a specific domain object, decoupled from categorization).
- [ADR-0006](./0006-budget-aggregate.md) — the `CategoryKey` string (`domain:<svc>` / `tag:<text>`) becomes a **`CategoryId`**. Finalized in [ADR-0025](./0025-budget-period-centric-and-category-targeted.md).

**Relates to:**

- [ADR-0022](./0022-wishlist-items-packages-and-derived-status.md) — `WishlistItem.ExternalRef` is unchanged and becomes an **auto-category source** (a line realizing a wishlist item inherits the item's domain).
- [ADR-0010](./0010-asset-aggregate.md) / [ADR-0005](./0005-aggregate-boundaries.md) — the `ExternalReference(string ServiceType, Guid ExternalId)` value object is retained for *specific-object* linking; it is no longer the line's category.

## Context

ADR-0006/0019 established a **dual-track** categorization model: a budget targets a `CategoryKey` that is either `domain:<serviceType>` (derived from a domain link) or `tag:<text>` (free text), with no fixed category list and no category CRUD. On `Line`, this was a single `Category: ExternalReference | Tag` union.

Three problems drove a rethink:

1. **The union forced an artificial choice.** A domain-linked line (`domain:board-games`) could not *also* be grouped in a user bucket (`hobby`) — domain identity ("what thing is this") and a user bucket ("how do I want to count this") are orthogonal, but the single-union field forced picking one. Workarounds (splitting one real payment into fake lines) misrepresent amounts.
2. **Free-text tags are categorization data with no identity.** Tags could not be renamed, could not carry metadata, and the "no fixed list" stance meant the Wallet had no category CRUD at all — every user started from an empty tag universe. The user wants a **managed** experience: useful built-in categories ready to go, plus the ability to create/delete their own.
3. **"Domain link" and "budgeting category" were overloaded onto one field.** A line's domain link serves two purposes — categorization *and* deep-linking to a specific domain object (Phase 2) / wishlist status — and conflating them made every change contentious.

The user explicitly scoped the replacement: a **traditional managed-category model**. There should be **special hardcoded categories linked to the other LifeOS domains** (Books, Board Games, Video Games), and **users can create/delete custom categories** to organize however they want. No tags, no dual-track.

Forces at play:

- A managed list reverses the documented "no fixed category list" principle — a deliberate philosophical shift, not a tweak.
- System categories are "hardcoded," but per-user editing of them would be wonky (divergent copies, no way to update uniformly). The standard seed-data + user-data pattern avoids this entirely (see Decision).
- The specific-domain-object link (which book, which game) is a separate concern from categorization (it links to a *service*, not a specific object). It already has a home (`ExternalReference`), so categorization can stop carrying it.
- In Phase 1 there are no Books/BoardGames/Steam services, so `ExternalRef` is always empty — the model is forward-compatible without v1 cost.

## Decision

### The `Category` entity (first-class)

```
Category {
  Id:           Guid,            // fixed Guid for system; client-assigned (ADR-0003) for user
  OwnerId:      string?,         // null for system; JWT sub (ADR-0004) for user categories
  Name:         string,
  ServiceTypes?: list<string>,   // system domain-linked categories only; maps this category to domain services
  System:       bool,            // true = immutable system category
  Archived:     bool,            // soft-archive (user categories only; system is never archived)
  CreatedAt:    DateTimeOffset,
}
```

Categories are now **first-class entities** (system constants or user documents), not free-text strings.

### System categories (the hardcoded, domain-linked ones)

- Defined **in code** as a static registry with **fixed Guids** — never per-user rows.
- **Seeded set:** **Books**, **Board Games**, **Video Games**.
- Each carries `ServiceTypes` (a list, so a category is not limited to one store): Books → `["books"]`, Board Games → `["board-games"]`, Video Games → `["steam"]` now (the only video-game service) and `["steam","epic",…]` later if more stores arrive. This is why the category is "Video Games," not "Steam."
- **Immutable:** users cannot create, delete, rename, or archive system categories. They only manage their own.
- **Always shown in v1** (no per-user hide flag); the user simply ignores ones they don't use.

### User categories (everything else)

- Per-user Marten documents (`OwnerId`-scoped), full CRUD: create, rename, delete. `ServiceTypes = null`, `System = false`.
- **Delete = soft-archive** (`Archived = true`): retired from the category picker, but historical lines/budgets still resolve by `CategoryId`. Rename is free (just updates the document; historical lines keep their `CategoryId` and show the new name, resolved at read).

### Read-time overlay (the "not wonky" seed pattern)

`GET /api/money/categories` returns the **union** of:

```
SystemCategories   (from the code registry, fixed Guids)
∪ UserCategories   (from the user's Marten documents, archived excluded from the picker)
```

System categories are **not copied into the user's table** and are never edited per-user. This is what avoids the wonkiness: there is no per-user edit of a hardcoded thing. The only per-user state that could ever touch a system category is a future *hide* flag (a `HiddenSystemCategories: list<Guid>` on the user — an additive overlay, not a mutation of the category) — deferred.

### Line categorization (amends ADR-0019)

```
Line {
  Description?:    string,
  Amount:          CurrencyAmount,                 // ADR-0008; lines share the entry's currency
  CategoryId?:     Guid,                           // the ONE budgeting category (nullable = uncategorized)
  ExternalRef?:    ExternalReference,              // direct link to a specific domain object (any line, not just wishlist)
  WishlistItemId?: Guid,                           // back-ref for the WishlistItemStatus projection (ADR-0022)
}
```

- The old `Category: ExternalReference | Tag` union is **gone**.
- `CategoryId` is the **single budgeting category** (one per line — traditional, no double-count across budgets).
- `ExternalRef` is the **specific-object link**, decoupled from categorization. **Any line may carry one**, not just wishlist lines. Self-contained: when a line is created from a wishlist item, `ExternalRef` is **copied from the wishlist item** so the line carries it directly; `WishlistItemId` is kept as the status back-ref (ADR-0022). A spontaneous (non-wishlist) domain purchase carries `ExternalRef` without `WishlistItemId`.

### Auto-categorize from a domain link

When a line has an `ExternalRef` (direct, or copied from a wishlist item) whose `ServiceType` matches a system category's `ServiceTypes`, the line's `CategoryId` **auto-defaults to that system category.** The user may override it (e.g., put a video game under a custom "Hobby" category) — the `ExternalRef` is preserved for deep-linking regardless; only the budgeting category changes.

### `CategoryId` as the budgeting key

Budgets target a **`CategoryId`** (see [ADR-0025](./0025-budget-period-centric-and-category-targeted.md)). The `BudgetActuals` projection groups `FlowRecorded` lines by `Line.CategoryId`. Uncategorized lines (`CategoryId = null`) contribute to no budget.

### Endpoints (CRUD)

- `GET /api/money/categories` — the overlay (picker excludes archived).
- `POST` / `PUT` / `DELETE /api/money/categories/{id}` — **user categories only.** A request targeting a system category (`System = true`) returns **403**.

### Multi-line purchases and categories

A multi-line `FlowRecorded`/`PlannedPurchaseAdded` may carry lines in several categories (each line has its own `CategoryId`). A single payment can therefore contribute to several budgets. One category *per line*; "this payment hits two budgets" is achieved via two lines, not two categories on one line.

## Deferred (Phase 2+)

- **`ExternalReference` snapshot caching.** When a line/wishlist item links a specific domain object, a short cached descriptor (title, thumbnail) is wanted so the UI need not query the owning service. This is a cross-cutting `ExternalReference` concern (affects `Line`, `WishlistItem`, planned purchases, future Assets), **not** a category concern, and it is **Phase 2** — in Phase 1 no domain service exists, so no `ExternalRef` is ever populated and there is nothing to snapshot. Adding an optional `Snapshot?` to `ExternalReference` later is non-breaking. Captured as a deferred ADR in the README. The mechanism (client-supplied snapshot at link time; Money never calls other services) and the inline-vs-separate-store sub-decision are detailed there.
- **`Media` system category** — one-line add to the registry when the Media service lands.
- **Per-user hide of system categories** — deferred; v1 always shows them.

## Consequences

Positive:

- A familiar managed-category model replaces the abstract dual-track/tag scheme — usable from day one, with built-in domain categories ready for Phase 2.
- System categories are clean code constants (no per-user divergence, no "edit the hardcoded thing" problem); user categories are simple CRUD documents.
- Categorization and domain-object linking are **decoupled**: `CategoryId` for budgets, `ExternalRef` for deep-linking/wishlist. A line can be re-categorized without losing its object link, and vice versa.
- One category per line → no double-count confusion across budgets.
- Auto-categorize removes a click (linking a domain item fills the category for free).

Negative:

- **Reverses a documented principle** ("no fixed category list"). Updates `apps/wallet/PLAN.md` §9, `apps/wallet/AGENTS.md`, and the Money `AGENTS.md` categorization sections, and amends ADR-0019/0006. All pre-implementation, so cost is zero.
- Categories are now first-class entities (system constants + user docs) — richer than projection-only strings, with a small amount of CRUD machinery.
- The "Tag UI / autocomplete" open questions in `apps/wallet/PLAN.md` §10 become moot (no tags).

Neutral:

- `ExternalReference` is no longer the line's category; it remains the value object for specific-object links elsewhere (Assets, wishlist). Its shape is unchanged.

## Alternatives Considered

1. **Keep the dual-track `ExternalReference | Tag` union (ADR-0019 as-is).** Rejected: forces domain XOR tag on a line; "no fixed list" leaves the user with an empty tag universe and no CRUD; conflates object-linking with categorization.
2. **Split into independent `Tag?` + `ExternalRef?` fields (allow a domain link AND a tag together).** Rejected by the user in favor of a managed category list: free-text tags are removed entirely; the user wants categories (system + user), not tags. `ExternalRef` is retained but only as the object link, not a budgeting track.
3. **Copy system categories into each user's table at signup (editable per user).** Rejected: divergent copies, no way to update system categories uniformly, ambiguous "is this the real Books category?" The seed-data + overlay pattern (system = code constants) avoids all of it.
4. **System categories as first-class Marten documents (stored, not code constants).** Rejected: they would need seeding, migration, and per-row protection; code constants with fixed Guids are simpler and referentially stable.
5. **Allow multiple categories per line.** Rejected: one category per line is simpler, avoids double-count across budgets, matches the traditional model. Multi-budget contribution is achieved via multiple lines.
6. **Model the domain link via `WishlistItemId` only (no direct `ExternalRef` on the line).** Rejected: the user wants **any** line to reference a domain object, not only wishlist lines. A spontaneous (non-wishlist) domain purchase must be linkable directly.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
