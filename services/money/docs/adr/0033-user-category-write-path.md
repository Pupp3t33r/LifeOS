# ADR-0033: User-category write path — name uniqueness, reversible archive/unarchive, management read

## Status

Accepted

Date: 2026-07-09

**Amends:**

- [ADR-0024](./0024-category-model.md) — the **Endpoints (CRUD)** section (`POST` / `PUT` / `DELETE /categories/{id}`, "delete = soft-archive") and the **"Rename is free (just updates the document)"** claim. This ADR pins the concrete write path ADR-0024 declared but deferred: it replaces `PUT`/`DELETE` with an explicit rename + reversible archive/unarchive, adds a **name-uniqueness invariant** (rename is no longer unconstrained), and gives the read an `includeArchived` mode. The `Category` shape, system/user split, seed pattern, overlay, and one-category-per-line decisions of ADR-0024 are unchanged.

**Relates to:**

- [ADR-0003](./0003-idempotency-via-client-assigned-uuids.md) — user-category ids are client-assigned UUIDs; create is idempotent on the id.
- [ADR-0011](./0011-wolverine-http-conventions.md) — the endpoints follow the Wolverine.Http conventions.
- [ADR-0012](./0012-production-schema-migration.md) — the durable uniqueness index is DDL that follows the no-runtime-auto-create policy in non-dev.
- [Wallet ADR-0008](../../../../apps/wallet/docs/adr/0008-categories-management-screen-and-colour-store.md) — the client management screen this write path serves; it mirrors the uniqueness rule for inline feedback and drives every write through the offline outbox.

## Context

ADR-0024 established the managed category model (system constants ∪ per-owner user documents) and *declared* a CRUD surface — `POST`/`PUT`/`DELETE /categories/{id}`, user-only, `DELETE` = soft-archive, `403` for a system target — but it deferred the concrete write behaviour. As of today:

- **No writer exists.** `GetCategoriesEndpoint` states it: user categories have no writer, so the overlay resolves to the three system constants only.
- **No Marten registration for `Category`.** `Program.cs` registers `UserPreferences` and `FxRate` explicitly; `Category` has none, so it would fall back to Marten defaults — primary key on `Id`, **no index or constraint on `Name`**.
- **No uniqueness rule.** ADR-0024 says "rename is free (just updates the document)," and there is no create validator. Nothing prevents two user categories named "Food", or a user category named "Books" shadowing the system one (they live in different stores — code constants vs. documents — and the overlay simply unions them).
- **The read excludes archived** (correct for the picker), but the Wallet management screen (Wallet ADR-0008) must *show* archived categories to rename or restore them.

Building the management screen forces these open points closed. Forces at play:

- The category **name is the only thing distinguishing rows** in the picker and on every canvas surface (name + colour dot). Two indistinguishable "Food" rows, or a shadow "Books", are a real hazard — uniqueness is a correctness concern, not a nicety.
- **Colour never reaches Money** (ADR-0003, Wallet ADR-0003). Create/rename payloads carry a name only; there is no colour field to key uniqueness against, so the name must carry it.
- Writes originate **offline** (Wallet ADR-0004): the client mints the id and enqueues the operation, so two devices can race a create. The server must be the authority, with a durable constraint behind the validator.
- "Delete" of a category that historical lines and budgets still reference by id must **not** be destructive — ADR-0024 already chose soft-archive; the missing half is a first-class, reversible **restore**.

## Decision

### Keying and registration

User-category `Id` is a **client-assigned UUID** (ADR-0003); system categories keep their fixed code constants. Register the document explicitly:

```csharp
options.Schema.For<Category>().Identity(x => x.Id);
```

### Name uniqueness invariant

A user category name is **unique per owner, case-insensitive, and trim-normalised**: leading/trailing whitespace is stripped and the name is stored as entered (trimmed); comparison is on `lower(trimmed(name))`. The check spans:

- **the owner's entire user-category set — active *and* archived** (archived names stay reserved, see below); and
- **the three system category names** (`SystemCategories.All`), so no user category can shadow "Books" / "Board Games" / "Video Games".

Enforced in two layers:

1. **A create/rename validator** runs the per-owner query (including the system-name check, which the DB index cannot see — system rows are code constants, not table rows). A violation returns **`422 Unprocessable Entity`** — deliberately *not* `409`: the Wallet offline outbox (Wallet ADR-0004) treats `409` as "the server already has this client-assigned id → applied, mark synced" (ADR-0003 idempotency). A genuine name clash must instead surface as a *failed* op the user resolves, which the drainer does for `422`. `409` stays reserved for a same-id/different-data idempotency edge.
2. **A durable partial unique index** is the backstop against the offline race: `unique (owner_id, lower(name)) where owner_id is not null`. Because archived rows carry `owner_id` too, the index enforces the reserved-archived-names rule automatically. It is DDL that follows ADR-0012 (created in dev auto-create; a pre-deploy migration elsewhere).

### Reversible archive / unarchive (replaces `DELETE`-as-soft-archive)

There is no hard delete and no `DELETE` verb. Retirement is an explicit, reversible state:

- **`POST /categories/{id}/archive`** — sets `Archived = true`. The category leaves the picker and the management screen's active groups; historical lines and budgets still resolve by `CategoryId` (ADR-0024).
- **`POST /categories/{id}/unarchive`** — clears `Archived`. Because archived names were never freed, **unarchive can never collide** — it always succeeds on the name.

### Archived categories stay editable

Rename applies to archived categories too (still subject to the uniqueness invariant). This is the escape hatch for reusing a reserved name: to reintroduce "Books" as a fresh, narrower category, first rename the archived holder — `"Books"` → `"Books_old"` — which frees `"Books"`. Colour is a client concern (Wallet ADR-0003) and is likewise editable while archived; Money is not involved.

### Endpoints (amends ADR-0024)

- **`GET /categories?includeArchived=false`** — the overlay. Default `false` preserves the ADR-0024 picker contract (active only); the management screen passes `true` to include the owner's archived categories. `CategoryResponse` gains an **`archived`** flag so a single client provider can serve both the picker (filters active) and the management screen (Wallet ADR-0008).
- **`POST /categories`** — `{ id: Guid (client-assigned), name }`. Idempotent on `id` (ADR-0003). Name validated.
- **`PATCH /categories/{id}`** — `{ name }`. Rename; name validated.
- **`POST /categories/{id}/archive`** · **`POST /categories/{id}/unarchive`**.
- **System target** (`System = true`) on any write returns **`403`**; a create/rename whose name collides (another user category — active or archived — or a system name) returns **`422`** (see above). A create repeating the same `id` with the same name is idempotent (`200`); the same `id` with different data is `409`.

## Consequences

Positive:

- Category rows are unambiguous everywhere: no duplicate names, no user category shadowing a system one, across active and archived alike.
- Retirement is reversible and non-destructive; historical resolution by `CategoryId` is untouched.
- Reserved archived names make **unarchive collision-free** — the awkward "the name is taken now" conflict on restore cannot happen; the user resolves naming *before* freeing a name, by renaming the archived holder.
- The offline create race is caught by the DB index even if two devices pass their local validators.
- The management screen gets exactly the read it needs (`includeArchived=true`) without weakening the picker's default.

Negative:

- Adds a validator, an index, and four write endpoints where ADR-0024 sketched three — more surface, all straightforward CRUD.
- The system-name portion of the uniqueness check lives only in the validator (system rows aren't in the table), so it is not enforced at the DB layer — acceptable, as system names are a fixed code set.
- A user who wants to truly remove a category (not archive) cannot; there is no hard delete in v1. Accepted — deletion would orphan historical `CategoryId` references.

Neutral:

- `includeArchived` is a query flag on the existing read, not a new endpoint.
- Trim-normalisation stores the display name as entered (trimmed); only comparison is lowercased, so casing the user chose is preserved for display.

## Alternatives Considered

1. **Allow duplicate names (ADR-0024's "rename is free", literally).** Rejected: the name is the sole distinguisher in the picker and on every canvas surface; duplicates and system-name shadows are a correctness hazard.
2. **Case-sensitive uniqueness.** Rejected: "Food" and "food" are indistinguishable to the reader; the constraint must be case-insensitive to mean anything.
3. **Free the name on archive (scope uniqueness to active only).** Rejected: makes unarchive ambiguous — a later category could claim the freed name, so restore would need a conflict flow. Reserving archived names keeps restore trivial; the user frees a name deliberately by renaming the archived holder.
4. **Hard `DELETE`.** Rejected: historical lines and budgets resolve by `CategoryId`; deleting orphans them. Soft-archive (ADR-0024) + reversible restore is the model.
5. **A single `PUT /categories/{id}` carrying `{ name, archived }`.** Rejected: explicit `archive`/`unarchive` sub-actions are idempotent, read clearly in the outbox and logs, and separate the reversible-state change from the rename.
6. **Validator only, no DB index.** Rejected as the sole mechanism: offline, concurrent creates can both pass their local validators; the partial unique index is the authority that makes the invariant hold under the race.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
