# Wishlist — design

Static HTML mockups for the **Wishlist management** surface — the backlog the Plan · Board tray *consumes* but never let you edit. This is the surface **[Wallet ADR-0005 §9](../../adr/0005-plan-destination-and-planning-views.md) left undesigned** ("managing the wishlist itself … needs its own surface"). The model is **[Money ADR-0022](../../../../../services/money/docs/adr/0022-wishlist-items-packages-and-derived-status.md)** (items + derived-status projection) as amended by **[Money ADR-0034](../../../../../services/money/docs/adr/0034-wishlist-commitment-state-and-planned-deadline.md)** — the **as-built** model (status enum `Idle · Planned · Financed · Bought`, plus the `Once`/`Reusable` recurrence flag) — and **[Money ADR-0030](../../../../../services/money/docs/adr/0030-external-domain-linking-and-wishlist-creation.md)** (optional estimate; external-domain link).

These are **design references, not app code.** The real screen is built in Flutter against the Calm tokens (`lib/app/theme/calm_tokens.dart`) and the Money wishlist API. Where a mockup and the ADRs/backend disagree, the backend wins.

## Shape — a flat list of wants, no grouping

The wishlist is a **flat list of individual wants** — one item per thing you want. **No grouping construct** (no folders, no bundles, no "packages"): **category filters + search** are the way around it. This is a deliberate correction — an earlier draft imported ADR-0022's `Package` "desire-side grouping" concept, which is faulty terminology; wishlist grouping was never a requirement and adds needless weight. (Grouping-of-things-bought-together, if it exists anywhere, is a purchase/fulfillment concern on the Order aggregate — ADR-0031 — not a wishlist concern.)

**Finding & filtering.** The default view is **Active** — everything still in play (Wishing + Planned + Paying off). **Bought** wants are hidden by default, tucked into a collapsed "N bought" row at the list end. The **category filter is an expanded menu** — a collapsed "All categories" trigger opens a **popover** on desktop / a **bottom sheet** on phone (see `wishlist-filter.html`), a **multi-select with OR semantics**: a want has exactly one category, so ticking several shows wants in *any* chosen category (an AND would always be empty). The trigger shows the active-filter count; **Clear** resets to all. Search matches names.

**Linking is out of scope for now — and that gates the domain categories.** Associating a want with an external domain object (ADR-0030's `ExternalRef`) is deferred — the create/edit sheets carry no Link field, and rows show no domain-link chip. Crucially, the **system/domain categories** — **Books · Board Games · Video Games** (ADR-0024, immutable, `ServiceTypes`-carrying) — are **link-derived**: a want lands in one only by being *linked* to that domain object (auto-categorized from the ref). They are **not hand-pickable** in the manual wishlist, so with linking deferred the manual picker offers **only ordinary user categories** (Electronics, Auto, Home, Kitchen, Photography, Food, …). The domain categories light up when linking ships. (An earlier draft wrongly showed a hand-created "Games" want — corrected: a Games/Books/Video-Games want can only arrive via linking.)

## Boundary (what this owns vs. what it doesn't)

- **This surface owns the _desire_ side** — the user-CRUD document: name, `Estimate` (`CurrencyAmount`, **optional** per ADR-0030 — a want may have no known price yet), notes, and the **one-time / repeat** flag (ADR-0034's `Once | Reusable`; UI says **Repeat**, not "reusable"). (The `ExternalRef` domain link exists in the model but its UI is deferred — see *Linking is out of scope* above.)
- **It does _not_ set status.** `Idle → Planned | Financed → Bought` is the **derived `WishlistItemStatus`** (ADR-0034) — `Planned` when the item is dropped on a month on the Board, `Financed` when it rides inside a payment plan, `Bought` when its line is paid. Shown read-only here; never hand-edited.
- **The Board is the assignment surface**, this is the **management** surface — two doors on the same items.

## Signature — the commitment track

Every want wears a compact **3-stop rail** — `Wishing → Committed → Bought` — showing how far it has travelled, double-encoded by position **and** colour. The middle stop is one of two branches (a want is planned on a month **or** financed in a plan — not both):

| Stage | Colour | Means |
|---|---|---|
| **Wishing** | muted | just an idea, not yet committed (`Idle`) |
| **Planned** | clay | earmarked on a month on the Board (`Planned`) |
| **Paying off** | denim | being paid in installments via a payment plan (`Financed`) |
| **Bought** | sage | paid for (`Bought`) |

(UI labels differ from the backend enum on purpose: `Idle·Planned·Financed·Bought` shows as **Wishing · Planned · Paying off · Bought** — "In a plan" was dropped because it read too close to "Planned".)

`Received` (Phase 3, Asset receipt) is out of scope for v1.

> ⚠️ **OPEN — how a _Repeat_ want shows its status is undecided.** The commitment track is a one-way acquisition **journey** (…→ Bought), which fits **One-time** wants but misrepresents **Repeat** wants (coffee, tea): a Repeat want never leaves the tray, each planning spawns an independent purchase, and the item only records its *latest* commitment (ADR-0034) — so "Bought" isn't terminal, concurrent instances (planned Oct *and* Nov) aren't representable, and "progress toward acquisition" is the wrong frame. The mockups currently pin Repeat wants at **Wishing** as a placeholder. Directions on the table (not yet chosen): **(1)** give Repeat rows their own recurring/"restock" indicator instead of the track; **(2)** a cyclical/looping track; **(3)** the same track with a non-terminal, resetting last stop. **To be decided before build.**

## Nav slotting — deliberately open

ADR-0005 §9 defers the wishlist's home to the **app-wide feature-map / IA review**. The mockup draws **candidate (b)**: a surface **pushed from the Plan · Board tray** (crumb `Plan · Board › Wishlist`, back chevron on phone), so it claims **no** bottom-bar slot yet. The other live candidates — Wishlist keeping its own destination, or a lens under Accounts — are not prejudged here.

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
| **[wishlist.html](./wishlist.html)** | **The wants backlog** — desktop + phone. Status summary, filter bar (status chips · category trigger · search · sort), and a flat list of wants, each wearing the commitment track. Create via `+ Add want`. |
| **[wishlist-filter.html](./wishlist-filter.html)** | **The category filter, expanded** — desktop popover + phone bottom sheet. Multi-select (OR) checkboxes with per-category counts, active-filter count on the trigger, Clear, and a "Show N wants" apply on phone. |
| **[wishlist-detail.html](./wishlist-detail.html)** | **The CRUD sheets** — desktop dialog + phone bottom sheet for each: **Add** (name, optional estimate + currency, category, one-time/repeat, note), **Edit** (same fields; **stage shown read-only** via a status banner, since `Idle·Planned·Financed·Bought` is derived — ADR-0034), and **Remove** (a confirm; removing a *committed* want warns that it also clears the plan/planned-buy that referenced it, and that nothing's been paid so no money is affected). |

## Not yet drawn (next)

- **⚠️ Repeat-want status display** — undecided; see the OPEN callout under *Signature* above. Blocks a faithful build of Repeat rows.
- **Empty state** (no wants yet) — an invitation to add the first want / pull one in from a domain app.
- **Category / currency pickers** and the **domain-item link picker** (ADR-0030) are shown as `›` rows here, not expanded.
