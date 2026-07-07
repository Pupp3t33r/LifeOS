# ADR-0004: Accessory binding model

## Status

Accepted

Date: 2026-07-07

## Context

Board-game accessories are heterogeneous in how they relate to the games they go with. Four real-world cases recur:

1. **Inseparable** — the accessory is consumed into the entity it's applied to and follows it on sale/disposal. Example: meeple stickers applied to a specific game's pieces. You don't sell the stickers separately from that game.
2. **Standalone** — the accessory is self-sufficient and usable with any compatible game. Example: metal coins, poker chips. Owned independently; no binding to a specific item.
3. **Primary-with-reuse** — the accessory is *intended* for one entity but can be used with multiple others. Example: a deluxe resource set designed for game X that also works with games Y and Z.
4. **Series** — the accessory is intended for a whole series/franchise of games, not a single one. Example: deluxe resources branded for a publisher's line.

A flat `accessory → game` foreign key cannot express all four. Flags on the accessory (`IsStandalone`, `IsInseparable`) are ad-hoc and don't capture the *target(s)*. The model must express both the **kind** of binding and, for the binding kinds that have targets, **which items** they bind to.

Forces at play:

- "Inseparable" has a real ownership consequence: disposing of the game disposes of the accessory. That's domain logic, not just a label.
- "Series" binds to a franchise concept, not a single item, so it can't be a simple FK to `CollectionItem`.
- One accessory can bind to multiple targets (primary-with-reuse), so the relationship is many-ended.
- The host needs to answer "what's attached to this game?" and "what can these coins be used with?" in both directions.

## Decision

Accessories are `CollectionItem`s (type `Accessory`) that participate in zero or more **`AccessoryBinding`** records. A binding carries a `Kind` discriminator and, depending on the kind, one or more targets:

| Kind | Targets | Ownership consequence |
|---|---|---|
| `Standalone` | none (no binding rows) | Independent; owned and disposed on its own |
| `Inseparable` | exactly one `CollectionItem` | Disposing the target disposes the accessory (follows it) |
| `PrimaryWithReuse` | one primary `CollectionItem` + N "usable-with" items | Owned independently; primary is the intended game |
| `Series` | a free-text `SeriesKey` (franchise) | Owned independently; binds to a series, not an item |

`AccessoryBinding` is a link entity: `{ AccessoryItemId, Kind, TargetItemId?, SeriesKey? }`. An accessory with no binding rows is implicitly `Standalone`. The binding invariants are enforced in the domain (the `Collection` aggregate or a dedicated binding domain service):

- `Inseparable` requires exactly one `TargetItemId` and a null `SeriesKey`.
- `PrimaryWithReuse` requires one primary target plus zero-or-more usable-with rows (distinguished by an ordinal/role on the row, or a separate flag).
- `Series` requires a non-empty `SeriesKey` and a null `TargetItemId`.
- All targets must belong to the **same `Collection`** as the accessory (the aggregate enforces this).

The "inseparable follows on disposal" consequence is implemented as domain logic in the disposal flow: when a `CollectionItem` is disposed, the domain checks for `Inseparable` bindings pointing at it and disposes the bound accessories in the same transaction.

## Consequences

Positive:

- All four real-world cases are expressible without overloading a single FK or inventing ad-hoc flags.
- The ownership consequence of `Inseparable` is explicit domain logic, not a UI convention the user must remember.
- Both directions are queryable ("what's attached to this game?" and "what does this accessory bind to?").
- A `Standalone` accessory is just an accessory with no binding rows — no special case in the schema.

Negative:

- `PrimaryWithReuse`'s "primary vs usable-with" distinction needs a role/ordinal field on the binding row, slightly more than a bare link table.
- `Series` binds to a free-text key, so two hosts typing the franchise differently won't auto-merge. Acceptable: series binding is about the host's own organization, not cross-host normalization.

Neutral:

- `AccessoryBinding` could live as its own aggregate or inside the `Collection` aggregate. The choice is deferred to implementation — the invariants (same-collection targets) suggest the `Collection` aggregate enforces them, but the binding entity itself is lightweight.

## Alternatives Considered

1. **Flat FK `accessory.GameId` + flags.** Rejected: cannot express primary-with-reuse (multiple targets) or series (no single item). Forces one accessory to one game, which is wrong for coins/chips used everywhere.
2. **Separate tables per kind (`InseparableAccessory`, `StandaloneAccessory`, ...).** Rejected: an accessory's kind is a property of how it's used, not what it is. A coin is the same row whether standalone or primary-with-reuse; the binding records the usage. Splitting tables duplicates the accessory entity across tables and complicates "list my accessories."
3. **No binding model — accessories are just items with a text "intended for" note.** Rejected: loses the `Inseparable` ownership consequence and makes "what's attached to this game?" unanswerable structurally.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
