# ADR-0036: Quantity, unit dimensions, and the unit-system display preference

## Status

Accepted

Date: 2026-07-12

**Amends:**

- [ADR-0019](./0019-universal-line-items.md) — `Line` gains two optional fields, `Quantity: decimal?` and `UnitDimension: UnitDimension?`.
- [ADR-0022](./0022-wishlist-items-packages-and-derived-status.md) — the `WishlistItem` document gains `CategoryId: Guid?` and `DefaultUnitDimension: UnitDimension?`.
- [ADR-0013](./0013-user-preferences-and-configurable-month.md) — the `UserPreferences` document gains `UnitSystem: UnitSystem` (default `Metric`).

**Relates to:**

- [ADR-0024](./0024-category-model.md) — the `CategoryId` the wishlist want now carries is the same managed category a `Line` carries.
- [ADR-0034](./0034-wishlist-commitment-state-and-planned-deadline.md) — §Board horizon: the per-period chip read (the "×0.5 kg" a want shows for each committed month) is the consumer this model enables. Its endpoint shape is an implementation detail, not a decision here.
- [Wallet design — wishlist](../../../../apps/wallet/docs/design/wishlist/README.md) — the locked Variant B surface whose decisions this ADR persists.

## Context

The Wallet wishlist management surface ([design](../../../../apps/wallet/docs/design/wishlist/README.md), Variant B) renders each want with **schedule chips** that show a per-month quantity: "×0.5 kg" of coffee beans one month, "×2" sleeves another. Building it forces three things the current model does not carry:

1. **A quantity + its kind on a line.** A planned purchase of coffee is not just "−5 USD" — it is "0.5 kg of coffee." `Line` (ADR-0019) has `Amount`, `CategoryId`, `WishlistItemId`, but no notion of *how much* or *what kind of thing* that amount buys. Without it the chip cannot show "×0.5 kg."
2. **A category on the want itself.** The wishlist surface has a category filter ("show only Groceries"). A `Line` carries a category, but a want — before it is ever planned — has none. Without `CategoryId` on `WishlistItem` the filter has nothing to filter on (system categories like Board Games are link-derived from `ExternalRef`, but user categories are not).
3. **Which unit symbols to show.** The same stored "0.5 Mass" renders as "0.5 kg" for one user and "0.5 lb" for another. That is a display choice, not a money fact.

Forces at play:

- **The dimension is a money fact; the symbol is a display fact.** "0.5 kg of coffee" and "0.5 Mass of coffee" are the same commitment; only the label differs. Storing the *dimension* (Mass) is honest and stable; storing the *symbol* (kg) couples the ledger to a display convention and forces a conversion every time the user switches systems. Money must never convert: a user who logs "0.5" in kilograms and switches to imperial should see "0.5 lb," not a silently-converted "1.1 lb" — the magnitude is what they typed.
- **The fields are additive and nullable.** `Line`, `WishlistItem`, and `UserPreferences` already exist with data; the new fields must default to null (or `Metric`) so old events/documents read back without migration. This is the same pattern ADR-0019 used for `CategoryId`/`WishlistItemId` and ADR-0034 for `Recurrence`.
- **`Line` is serialized directly in responses** (planned-purchase, flow, recurring responses all embed `list<Line>`), with no per-response DTO. The unit enums therefore ride the wire as their underlying integers (the System.Text.Json default) — the same way `SavingsMovementSource` already rides `RecordSavingsMovementResponse` directly. No hand-mapping, no converter, no per-type DTO: the request and response records carry the enum types directly.
- **Category on the want is user-category only.** System categories (Books/Board Games/Video Games) are link-derived from a want's `ExternalRef` (ADR-0024/0030); they are never copied into user storage. So `WishlistItem.CategoryId` holds a *user* category, exactly mirroring how a `Line` carries its (possibly user) `CategoryId`.

## Decision

### `Line` gains `Quantity` + `UnitDimension` (amends ADR-0019)

```
Line {
  ...ADR-0019 fields (Description, Amount, CategoryId, WishlistItemId)...
  Quantity?:      decimal?,          // optional magnitude: 0.5, 2, 10
  UnitDimension?: UnitDimension?,    // optional kind: Pieces | Mass | Volume | Length
}
```

Both additive and nullable; old events deserialize them as null (no migration, no upcaster — ADR-0002 dev mode). `UnitDimension` is a closed, dimensionless enum — it names a *kind of quantity*, never a unit:

| Dimension | Symbols (client-chosen, by UnitSystem) |
|---|---|
| `Pieces` | *(none — a bare count)* |
| `Mass` | kg (Metric) / lb (Imperial) |
| `Volume` | L (Metric) / gal (Imperial) |
| `Length` | m (Metric) / ft (Imperial) |

Money stores the dimension and the magnitude. It **never** stores the symbol and **never** converts between systems. A `Quantity` with no `UnitDimension` (or `Pieces`) renders as a bare "×N". A `Line` may carry a `Quantity` + `UnitDimension` with no `WishlistItemId` (a spontaneous planned purchase of "2 m of cable") — the unit fields are independent of the wishlist link.

### `WishlistItem` gains `CategoryId` + `DefaultUnitDimension` (amends ADR-0022)

```
WishlistItem {
  ...ADR-0022/0034 fields...
  CategoryId?:            Guid?,           // a USER category (system ones are link-derived)
  DefaultUnitDimension?:  UnitDimension?,  // UI default for this want's quantity unit
}
```

`CategoryId` is the want's user category — what the wishlist category filter keys on. System categories are *not* stored here: a want whose `ExternalRef` points at a board game reads as "Board Games" by derivation (ADR-0024/0030), and that overlay is computed at read time, never copied into the field. `DefaultUnitDimension` is a UI convenience the client pre-fills when the user plans an instance of the want (e.g. a "Coffee beans" want defaults to `Mass`); it carries no domain rule. Both default null.

### `UserPreferences` gains `UnitSystem` (amends ADR-0013)

```
UserPreferences {
  ...ADR-0013 fields (MonthStartDay, DisplayCurrency)...
  UnitSystem: UnitSystem,   // Metric | Imperial; default Metric
}
```

A display-only preference selecting which unit **symbol** the client renders for a given `UnitDimension`. Switching it relabels every quantity's symbol (kg↔lb, L↔gal, m↔ft) **without touching any stored magnitude** — Money performs no conversions. Default `Metric`. Unlike `MonthStartDay`, it is **not** locked after the first close: it re-buckets nothing and changes no money figure, so it is freely settable at any time. One new endpoint, `PUT /api/money/preferences/unit-system` (`"metric"` | `"imperial"`); the existing `GET /preferences` and the two other `PUT`s return the field.

### Wire shape

`UnitDimension` and `UnitSystem` ride the wire as their underlying integers (the System.Text.Json default) — `UnitDimension` as 0/1/2/3, `UnitSystem` as 0/1. The request DTOs (`PlannedPurchaseLine`, the wishlist create/edit requests, `SetUnitSystemRequest`) and the response DTOs (`WishlistItemResponse`, `PreferencesResponse`) carry the enum types directly; `Line.UnitDimension` rides `Line` the same way, with no DTO. No hand-mapping, no converter: this matches how `SavingsMovementSource` already rides `RecordSavingsMovementResponse` directly, and how every `Line` field already rides the ~10 response types that embed it. (An earlier draft hand-mapped these to lowercase strings and minted a converter for `Line`; it was dropped as needless complexity — the integer default is zero code and the contract already uses it.) Marten stores enums as integers (`EnumStorage.AsInteger`), so wire and storage agree.

## Consequences

Positive:

- The wishlist chip can render "×0.5 kg" from a planned line's `Quantity` + `UnitDimension`, with the symbol chosen by the owner's `UnitSystem` — no client-side conversion, no server-side conversion, ever.
- The category filter has a real field to filter on (`WishlistItem.CategoryId`), symmetric with how a `Line` carries its category.
- A user switching unit systems sees honest relabeling (the magnitude they typed is preserved); nobody silently re-denominates their history.
- All three amendments are additive/null-defaulting — no event migration, no upcaster, no document rewrite. The `Line` change is the event-sourced core (AGENTS §9 #3), but it is the lowest-risk kind: trailing optional parameters that old events deserialize as null.

Negative:

- `Line` now carries two more nullable fields that almost every line leaves null (most lines are a bare amount). Acceptable: they are optional and the common case pays only two null checks.
- The chip read (ADR-0034 §Board horizon) must compose `Line.Quantity`/`Line.UnitDimension` per period — a read composition recorded as a consumer here, implemented separately. Its endpoint shape is not decided by this ADR.
- The unit enums ride the wire as raw integers, so the JSON is less self-documenting (`"unitDimension":1` rather than `"unitDimension":"mass"`). Accepted: it is the zero-code System.Text.Json default, it matches how `SavingsMovementSource` already rides responses, and the client maps the integers to enum names at the boundary. The string alternative (hand-mapped lowercase values + a converter for `Line`) was built and dropped as over-engineering.

Neutral:

- `UnitDimension` is deliberately coarse (four members). It captures *kind* for symbol-selection, not precision; "1 cup" and "1 L" are both `Volume`, and the client picks the symbol. Money does not model teaspoon-vs-cup — that is a client display refinement, not a money fact.
- `UnitSystem` defaults `Metric`; an absent `UserPreferences` document (the onboarding-incomplete case) reads as `Metric`, consistent with ADR-0013's "absent = defaults."

## Alternatives Considered

1. **Store the unit symbol string on the line (`"kg"`).** Rejected: it couples the ledger to a display label, is ambiguous ("lb" vs "lbs", "L" vs "l"), and forces a conversion on every system switch. The dimension is the stable money fact; the symbol is rendering.
2. **Store converted magnitudes (convert on UnitSystem change).** Rejected as dishonest: a user who typed "0.5" in kilograms expects "0.5" to still be "0.5" after switching — relabeled, not re-denominated. Conversion also introduces rounding and is a one-way door; the ADR makes it unrepresentable.
3. **Per-line `UnitSystem` (each line picks its own system).** Rejected: the unit system is a single user-level display preference, not a property of a purchase. Per-line systems would multiply symbols inconsistently and solve no real need.
4. **A finer `UnitDimension` (teaspoon, cup, meter, foot…).** Rejected: Money only needs the *kind* to select a symbol family; the specific unit is a client display choice. A closed four-member enum keeps the server honest without modelling a units library it has no business reason to own.
5. **Expose the unit enums as lowercase strings on the wire.** An earlier draft did this: a `UnitMapping` class hand-mapped the enums to `"mass"`/`"metric"` in the DTOs, and a scoped `[JsonConverter]` (then a global converter) carried `Line.UnitDimension` as a string. Rejected as needless complexity — the contract already ships directly-embedded enums as integers (`SavingsMovementSource`), the integer is System.Text.Json's zero-code default, and the string version added a mapping class plus a converter for no functional gain. The global converter was worse still: it re-serialized *unrelated* enum-typed response members as strings, breaking their existing integer readers.
6. **Model the category on the want as a system-or-user union (store system category ids too).** Rejected: system categories are link-derived from `ExternalRef` at read time (ADR-0024/0030 overlay) and must never be copied into user storage. `WishlistItem.CategoryId` holds a user category only; the system category is computed, not stored.

---

**Rules:** Once this ADR is marked **Accepted**, its body is frozen. To change the decision, write a new ADR that **Supersedes** it — do not edit this file.
