# ADR-0008: Categories management screen and the device-local colour-override store

## Status

Accepted

Date: 2026-07-09

**Realizes:** [Wallet ADR-0003](./0003-category-colour-system.md) — the deferred pieces: the actual **device-local colour-override store** ("stored device-local, keyed by `CategoryId`" — never built) and the **Settings → Categories** surface (the "12-swatch picker" it named but did not specify).

**Relates to:** [Money ADR-0024](../../../../services/money/docs/adr/0024-category-model.md) (the managed category model this screen edits), [Money ADR-0033](../../../../services/money/docs/adr/0033-user-category-write-path.md) (the write path — uniqueness, archive/unarchive, `includeArchived` read — this screen drives), [Money ADR-0003](../../../../services/money/docs/adr/0003-idempotency-via-client-assigned-uuids.md) (the client mints the category `Guid`), [Wallet ADR-0002](./0002-navigation-and-information-architecture.md) (Settings as a secondary surface above the shell), [Wallet ADR-0004](./0004-offline-first-sync.md) (category writes go through the outbox), [Wallet ADR-0001](./0001-app-localization.md) (the client-only, device-local preference precedent the colour store follows).

## Context

Wallet ADR-0003 chose a curated 12-slot Calm palette, deterministic `CategoryId`-derived defaults, and **device-local overrides** as the colour model, and named **Settings → Categories** as the place to recolour — but it deferred the override store ("in the same client-preference layer … via a small store") and never specified the screen. The category model itself (Money ADR-0024) and now its write path (Money ADR-0033) are settled. Today the Wallet only *reads* categories (`categoriesProvider`, active-only) for the add-entry picker; there is no management surface and no colour store.

The screen has to do four things that pull in different directions: recolour any category (including system ones — locked name, recolourable), rename/create/archive/restore the user's own, find a category by name (including archived, to restore it), and stay coherent with the app's established Calm grammar. The full visual design is specified in [`docs/design/settings/categories.html`](../design/settings/categories.html); this ADR records the architectural decisions behind it.

Forces at play:

- **Colour is presentation, never domain** (Wallet ADR-0003): overrides live on the device, the picker mints no colour to the server, and the resolver is `override ?? deterministic-default(CategoryId)`.
- **Settings is a secondary surface**, not a nav destination (Wallet ADR-0002) — the current Settings page is a single searchable page of *inline* controls, with no navigation-row precedent.
- **Writes are offline-first** (Wallet ADR-0004): create/rename/archive/unarchive must enqueue on the outbox, with the client minting the id (Money ADR-0003), and reconcile a server `409` (name conflict) after drain.
- **The picker's read must not change.** It relies on the active-only overlay (Money ADR-0024); the management screen needs archived too (Money ADR-0033's `includeArchived`).

## Decision

### Placement — a dedicated screen, reached by a navigation row

Categories management is a **dedicated full screen at `/settings/categories`**, a sibling of `/settings` sitting above the shell with a back affordance (Wallet ADR-0002). It is reached from a **navigation row** on the Settings page ("Categories · Manage your categories") — the first row on Settings that *navigates* rather than hosting an inline control. A full CRUD list (search, create, rename, recolour, archive/restore, system vs. yours) is too heavy to live inline among the toggles and dropdowns.

### Screen structure

A single scroll (full spec in the design doc):

- **A search field pinned on top** filters **Yours + System + Archived** by name (case-insensitive substring), mirroring the existing Settings search; empty groups drop out of the results. **Archived is always in scope** — a retired category is found and restored by typing its name, without expanding the Archived section first.
- **Yours** — user categories, full lifecycle. Tapping a category's **swatch** opens the 12 Calm slots **inline, in place** (the selected slot ringed and named); the same opened drawer holds **Rename** and **Archive**. A ghost row creates a new category.
- **System** — Books / Board Games / Video Games: recolourable swatch, a locked-name marker, no Rename/Archive (Money ADR-0024).
- **Archived** — collapsed with a count; rows open to the same drawer (recolour + **Rename** + **Unarchive**), so a reserved name can be freed by renaming the archived holder (Money ADR-0033).

### The device-local colour-override store

A category's colour override is stored **on the device, keyed by `CategoryId`**, in the same client-preference layer the locale (Wallet ADR-0001) and app-lock (Money ADR-0014) use — `flutter_secure_storage`, holding a small JSON map `categoryId → palette slot` under one key, **not** the server (and not drift, which backs the sync read-models/outbox, ADR-0004 — a preference map is the `ThemeStore`/`LocaleStore` shape, not a queryable table). The resolver stays `override ?? deterministicDefault(CategoryId)` (Wallet ADR-0003), so a category without an override keeps its stable, cross-device default. **Cross-device sync of overrides remains deferred** (Wallet ADR-0003) — defaults are already device-stable; only manual overrides are per-device until a client-preferences sync exists.

### Writes go through the outbox; the server is the authority

Create / rename / archive / unarchive enqueue operations on the offline outbox (Wallet ADR-0004); the client mints the category `Guid` (Money ADR-0003). The client **mirrors Money ADR-0033's uniqueness rule** (case-insensitive, trim-normalised, spanning active + archived + system names) to show an **inline error before enqueue** — but the server stays source of truth. A uniqueness clash that only shows up on the server (the offline cross-device race) comes back as **`422`**, which the drainer marks **failed** (not `409` → the drainer would swallow that as "already applied"); the failed op is surfaced for the user to rename. Recolour is **not** an outbox operation — it writes only to the local colour store and never round-trips.

### Reads — one source, filtered client-side

There is **one categories provider**, fetching the full overlay including archived (`GET /categories?includeArchived=true`, Money ADR-0033; the `CategoryResponse` carries an `archived` flag). The management screen reads the whole list; the add-entry **picker reads a derived active-only view** (`.where((x) => !x.archived)`). A single fetch and a single cache: an archive/unarchive invalidates once and both surfaces update, with no two-cache drift. This costs the client `Category` model (and the `CategoryResponse` contract) an `archived` field — the client now legitimately knows about archived categories, so that is honest, not overhead.

## Consequences

Positive:

- Colour sits at the right layer — a device-local display preference — matching Wallet ADR-0003 and adding nothing to Money's surface; recolour is instant and offline (no round-trip).
- The management surface is coherent with the app: Calm cards, the letter-spaced eyebrows, and an inline named palette that reuses the app's own curated colour vocabulary rather than a generic wheel.
- Search-including-archived plus in-place Rename/Unarchive makes the reserved-name workflow (Money ADR-0033) reachable without a separate "manage archived" mode.
- Offline writes and the client-side uniqueness mirror give immediate feedback while the server (via the ADR-0033 index) remains the authority under the create race.

Negative:

- Introduces the **first navigation row** on the otherwise inline Settings page — a small break from the "everything inline" pattern, justified by the CRUD weight.
- Manual colour overrides don't sync across devices yet (inherited from Wallet ADR-0003); a recolour on the phone won't appear on the desktop. Mitigated by device-stable defaults.
- The `CategoryResponse` contract and the client `Category` model gain an `archived` field so one provider can serve both surfaces (the picker filters it out). A small, honest addition — but it does touch the wire shape.

Neutral:

- The colour store reuses the existing device-preference persistence (`flutter_secure_storage`, as `ThemeStore`/`LocaleStore`) — no new pattern; just a JSON map instead of a scalar value.
- The full visual spec lives in `docs/design/settings/categories.html`; where it and this ADR disagree, this ADR wins (design docs are references, not app code).

## Alternatives Considered

1. **An inline expandable group on the Settings page (no dedicated screen).** Rejected: create/rename/recolour/archive/restore across three sub-lists is far too much to live inline among single-control rows; a CRUD list wants its own surface.
2. **A modal colour picker anchored to the swatch** (the earlier `home/categories.html` sketch). Rejected in favour of the inline named palette: it reads better on a phone and puts recolour, Rename, and Archive in one opened context. Recorded in the design doc.
3. **Store the override on Money's `Category`.** Rejected: colour changes nothing the server computes (Wallet ADR-0003, Money ADR-0024) — it would force one colour across devices and themes and breach the server-owns-only-server-affecting-config rule.
4. **Sync overrides across devices now.** Rejected: no client-preferences sync channel exists; defaults are already cross-device-stable, so per-device overrides are acceptable for solo v1 (deferred with the rest of Wallet ADR-0003's sync).
5. **Recolour through the outbox like the other writes.** Rejected: colour never touches Money, so a server round-trip is pointless; recolour writes to the local store only and is available even while offline and even for categories with a pending create.
