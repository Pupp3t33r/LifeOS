# Wishlist — design

Static HTML mockups for the **Wishlist management** surface — the backlog the Plan · Board tray *consumes* but never let you edit. This is the surface **[Wallet ADR-0005 §9](../../adr/0005-plan-destination-and-planning-views.md) left undesigned** ("managing the wishlist itself … needs its own surface"). The model is **[Money ADR-0022](../../../../../services/money/docs/adr/0022-wishlist-items-packages-and-derived-status.md)** (items + derived-status projection) as amended by **[Money ADR-0034](../../../../../services/money/docs/adr/0034-wishlist-commitment-state-and-planned-deadline.md)** — the **as-built** model (status enum `Idle · Planned · Financed · Bought`, plus the `Once`/`Reusable` recurrence flag) — and **[Money ADR-0030](../../../../../services/money/docs/adr/0030-external-domain-linking-and-wishlist-creation.md)** (optional estimate; external-domain link).

> **Amendments recorded here (to be codified as ADRs before build):**
> **(a)** a `CategoryId?` is added to the want (amends ADR-0022/0034 — see *Boundary*);
> **(b)** **Variant B** — every want (One-time *and* Repeat) wears a coloured **stage dot** + its **schedule as month chips**; the 3-stop commitment track is dropped (resolves the *Signature* open item);
> **(c)** Wishlist gets its **own bottom-bar nav slot** (amends Wallet ADR-0002/0005 — see *Nav slotting*);
> **(d)** `Line` gains `Quantity` + a generic `UnitDimension` (`Pieces · Mass · Volume · Length`), and `UserPreferences` gains a cosmetic metric/imperial `UnitSystem` (amends ADR-0019/0013 — see *Quantity & units*);
> **(e)** the schedule is a **read composition** over the planned-purchase store (ADR-0034 §"Board horizon") — no new domain rules.

These are **design references, not app code.** The real screen is built in Flutter against the Calm tokens (`lib/app/theme/calm_tokens.dart`) and the Money wishlist API. Where a mockup and the ADRs/backend disagree, the backend wins.

## Shape — a flat list of wants, no grouping

The wishlist is a **flat list of individual wants** — one item per thing you want. **No grouping construct** (no folders, no bundles, no "packages"): **category filters + search** are the way around it. This is a deliberate correction — an earlier draft imported ADR-0022's `Package` "desire-side grouping" concept, which is faulty terminology; wishlist grouping was never a requirement and adds needless weight. (Grouping-of-things-bought-together, if it exists anywhere, is a purchase/fulfillment concern on the Order aggregate — ADR-0031 — not a wishlist concern.) The `Package` document, `WishlistItem.PackageId`, and package CRUD exist in the Money service and the Wallet outbox plumbing (ADR-0022), but are **intentionally left dormant** — there is no package UI here; grouping may be revisited if a real need appears.

**Finding & filtering.** The default view is **Active** — everything still in play (Wishing + Planned + Paying off). **Bought** wants are hidden by default, tucked into a collapsed "N bought" row at the list end. The **category filter is an expanded menu** — a collapsed "All categories" trigger opens a **popover** on desktop / a **bottom sheet** on phone (see `wishlist-filter.html`), a **multi-select with OR semantics**: a want has exactly one category, so ticking several shows wants in *any* chosen category (an AND would always be empty). The trigger shows the active-filter count; **Clear** resets to all. Search matches names.

**Linking is out of scope for now — and that gates the domain categories.** Associating a want with an external domain object (ADR-0030's `ExternalRef`) is deferred — the create/edit sheets carry no Link field, and rows show no domain-link chip. Crucially, the **system/domain categories** — **Books · Board Games · Video Games** (ADR-0024, immutable, `ServiceTypes`-carrying) — are **link-derived**: a want lands in one only by being *linked* to that domain object (auto-categorized from the ref). They are **not hand-pickable** in the manual wishlist, so with linking deferred the manual picker offers **only ordinary user categories** (Electronics, Auto, Home, Kitchen, Photography, Food, …). The domain categories light up when linking ships.

## Boundary (what this owns vs. what it doesn't)

- **This surface owns the _desire_ side** — the user-CRUD document: name, **category** (a `CategoryId?` on the want — amends ADR-0022/0034; the picker offers **user categories only**, since the system/domain categories are link-derived), **unit** (a default `UnitDimension?` — see *Quantity & units*; Repeat sheets show the picker, One-time implies Pieces), `Estimate` (`CurrencyAmount`, **optional** per ADR-0030 — a want may have no known price yet), notes, and the **one-time / repeat** flag (ADR-0034's `Once | Reusable`; UI says **Repeat**, not "reusable"). (The `ExternalRef` domain link exists in the model but its UI is deferred — see *Linking is out of scope* above.)
- **It does _not_ set status.** `Idle → Planned | Financed → Bought` is the **derived `WishlistItemStatus`** (ADR-0034) — `Planned` when the item is dropped on a month on the Board, `Financed` when it rides inside a payment plan, `Bought` when its line is paid. Shown read-only here; never hand-edited.
- **The Board is the assignment surface**, this is the **management** surface — two doors on the same items.
- **Removing a committed want does _not_ cascade.** The planned buy keeps its line but stops tracking the want; clear it on the Board if you want it gone. Nothing's been paid, so no money is affected — and the Remove confirm says exactly that.

## Signature — one chip language (stage dot + schedule)

Every want — One-time **and** Repeat — wears the same thing: a coloured **stage dot** + its **schedule as month chips**. The earlier 3-stop commitment track is **dropped** (this was the open item; resolved as **Variant B**). The track was a one-way "journey" that fit One-time wants but misrepresented Repeat wants (which restock — never terminal, concurrent instances, only a latest-commitment in the status doc), and it under-used the schedule data the projection already collects. One render path for both kinds.

| Stage (dot) | Colour | Means |
|---|---|---|
| **Wishing** | hollow | just an idea, not yet committed (`Idle`) |
| **Planned** | clay | earmarked on a month on the Board (`Planned`) |
| **Paying off** | denim | being paid in installments via a payment plan (`Financed`) |
| **Bought** | sage | paid for (`Bought`) — hidden in the collapsed row |

(UI labels differ from the backend enum on purpose: `Idle·Planned·Financed·Bought` shows as **Wishing · Planned · Paying off · Bought**. `Received` is Phase 3, out of scope for v1.)

### Schedule chips

- **Window:** current + future only — paid history lives in Activity, so chips never accumulate, and no year is shown.
- **States:** outline = planned (unpaid); filled `✓` = paid this cycle.
- **`×N`** = the **item count** for that month, summed across orders (two packs of tea in Oct → `Oct ×2`). For non-Pieces dimensions the cosmetic unit symbol shows (`Oct ×0.5 kg`) — see *Quantity & units*.
- **Grouping:** chips group by (month, paid-state, unit); a rare financed Repeat wears an `in <plan>` tag instead of a month chip.
- **Source:** a read composition over the planned-purchase store (`Line.WishlistItemId` → periods), sanctioned by ADR-0034 §"Board horizon" — no new domain rules; the projection's `ActivePlannedEntryIds` set already collects the instances.

### Roll-up rule

A Repeat want counts as **Planned** while it has any unpaid instance (summary-level **Bought** is One-time-only), so a Repeat with a paid instance + pending instances doesn't vanish into "Bought."

## Quantity & units

A want (and every purchase line) can carry a quantity. To avoid the units-of-measurement rabbit hole, **the backend stores only a generic dimension** and the **symbol is a UI-only cosmetic**:

- `Line` (amends **ADR-0019**) gains `Quantity: decimal?` + `UnitDimension: { Pieces, Mass, Volume, Length }?`. `Amount` stays the **line total** (keeps `Σ lines = entry total`, ADR-0026); `Quantity` is the count/magnitude, absent ⇒ treat as 1. Fractional allowed for non-Pieces (frontend validation; the backend stores `decimal` regardless of dimension).
- `WishlistItem` (amends **ADR-0022/0034**) gains a default `UnitDimension?` — saves clicks (planning/buying it inherits the want's dimension). The picker shows on Repeat sheets; One-time implies Pieces and hides it.
- `UserPreferences` (amends **ADR-0013**) gains `UnitSystem { Metric, Imperial }` (default **Metric**) — **display-only**. It maps a dimension to its symbol at render time:

  | Dimension | Metric | Imperial |
  |---|---|---|
  | Pieces | — (count, integer) | — |
  | Mass | kg | lb |
  | Volume | L | gal |
  | Length | m | ft |

- **No conversions, ever** — not even at switch time. Changing `UnitSystem` **relabels every Mass/Volume/Length quantity without touching its number** (a 2 stays a 2 across a kg↔lb relabel; this is a finance annotation, not a measurement). The kg/lb/gal/ft symbols are **never stored on a line** — they're rendered from the preference. The user sees their chosen units everywhere in the UI; the backend sees only the dimension.
- Per-unit pricing is **future**; for now `Estimate` stays a total expected price, independent of `Quantity`.

## Nav slotting — own bottom-bar destination

Wishlist gets its **own slot in the bottom nav / rail** — `Home · Plan · Wishlist · Activity · Accounts` (beside Plan, which consumes it on the Board). This **amends Wallet ADR-0002** (which rejected five destinations on phone bottom-bar capacity) and **settles ADR-0005 §9**'s deferral. The earlier "pushed from the Board tray" candidate (b) is dropped — Wishlist is a destination, not a sub-surface, so the crumbs/back-chevrons the old mockups carried were removed. A short amending Wallet ADR records the 5-slot reversal.

## Conventions — frames ship only what's real

The device frame in each mockup shows **only what ships in the product**. Legends, references, and explanatory annotations that aren't part of the real UI live **outside the frame** (the masthead/notes above it) or in this README — never inside the frame. If a design needs a legend to be understood, that's a signal the design isn't self-evident enough — fix the design, don't annotate it. *(Holds for all Wallet design mockups — plan · recurring · home · wishlist.)*

## Viewing

Self-contained (Calm palette inline; Bricolage Grotesque + Spline Sans from Google Fonts). `file://` is blocked by the font CDN, so serve the folder:

```bash
cd apps/wallet/docs/design/wishlist
python -m http.server 8000
# then open http://localhost:8000/wishlist.html
```

## The files

| File | What it shows |
|---|---|
| **[wishlist.html](./wishlist.html)** | **The wants backlog** — desktop + phone. Status summary, filter bar (status chips · category trigger · search · sort), and a flat list of wants where every row wears a **stage dot + schedule chips** (`×<qty> <unit>` for Repeat, e.g. `Oct ×0.5 kg`, `Oct ×2`). Includes the **dimension → symbol** table. Create via `+ Add want`. |
| **[wishlist-filter.html](./wishlist-filter.html)** | **The category filter, expanded** — desktop popover + phone bottom sheet. Multi-select (OR) checkboxes with per-category counts, active-filter count on the trigger, Clear, and a "Show N wants" apply on phone. |
| **[wishlist-detail.html](./wishlist-detail.html)** | **The CRUD sheets** — desktop dialog + phone bottom sheet for each: **Add** (name, optional estimate + currency, category, one-time/repeat, **unit dimension** for Repeat, note), **Edit** (same fields; **stage shown read-only** via a status banner, since `Idle·Planned·Financed·Bought` is derived — ADR-0034), **Edit Repeat** (the schedule shows as read-only month chips — instances are edited on the Board), and **Remove** (a confirm; removing a *committed* want warns that its planned buy **keeps its line but stops tracking the want** — no cascade; nothing's been paid, so no money is affected). |

## Resolved in this pass

- **✅ Variant B committed** — every want wears a stage dot + schedule chips; the commitment track is dropped. Drawn in `wishlist.html`.
- **✅ Quantity & units** — `Quantity` + generic `UnitDimension` on `Line`; cosmetic metric/imperial `UnitSystem` on `UserPreferences`; no conversions. See *Quantity & units*.
- **✅ `×N` = item count** — summed across orders within a (month, paid-state) group.
- **✅ Nav slot** — Wishlist has its own bottom-bar slot (amends ADR-0002/0005); see *Nav slotting*.
- **✅ Category on the want** — the picker is in the Add/Edit sheets (user categories only).
- **✅ Honest remove** — no cascade; the planned buy keeps its line.

## Not yet drawn (next)

- **Empty state** (no wants yet) — an invitation to add the first want / pull one in from a domain app.
- **Category / currency / unit pickers** and the **domain-item link picker** (ADR-0030) are shown as `›` rows here, not expanded.
