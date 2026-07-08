# Plan tab — design

Static HTML mockups for the **Plan destination**. **Frozen by [Wallet ADR-0005](../../adr/0005-plan-destination-and-planning-views.md)** (Accepted 2026-07-08) — where a mockup and the ADR disagree, the ADR wins.

ADR-0005 reverses a call the Home pass made: Plan was **dissolved** as a destination ("its instances live on Home; its definitions are edited in context") and the nav slot went to Wishlist — see [`../home/README.md`](../home/README.md) §3. It's reinstated because two gaps surfaced that Home can't hold (the app shell still carried a stubbed `/plan` route, `lib/features/money/ui/plan/plan_screen.dart`):

- **No home for definitions.** Home deals in *instances* — this period's rows. To edit the *definition* behind one (an Ongoing amount, a plan) you have to find its instance on the right month. There's no period-agnostic place a definition lives.
- **No forward view.** Home shows one period. "What am I committed to over the next few months?" has no screen.

Each direction lets Plan **assign** wishlist items — surfacing idle wants for planning. Note this is item *assignment*, not wishlist *management*: editing the backlog and associating items with external domain objects (ADR-0022) stays a separate, still-undesigned surface, so the Wishlist destination is **not** dissolved (nav slotting is left open — see ADR-0005).

These are **design references, not app code.** The real screens are built in Flutter against the Calm tokens (`lib/app/theme/calm_tokens.dart`) and the Money API. Where a mockup and the ADRs/backend disagree, the backend wins.

## Model guardrails (held in all three)

- **A Payment plan is immutable except _Cancel_** ([ADR-0028](../../../../../services/money/docs/adr/0028-recurring-contents-at-root.md)) — so its row opens **Manage** (progress + Cancel, refund / no-refund), never a field edit.
- **A planned purchase is period-local** ([ADR-0018](../../../../../services/money/docs/adr/0018-planned-purchases-on-accounting-period.md)) — shown under the period it's filed on, not as a timeless object.
- **The word "recurring" stays out of the UI** — user-facing: *Ongoing*, *Payment plan*, *Planned purchase*, *Mark paid*.
- Nav is drawn `Home · Plan · Activity · Accounts` to match the current app shell.

## Viewing

Self-contained (Calm palette inline; Bricolage Grotesque + Spline Sans from Google Fonts). `file://` is blocked by the font CDN, so serve the folder:

```bash
cd apps/wallet/docs/design/plan
python -m http.server 8000
# then open http://localhost:8000/plan-options.html
```

## The files

Plan is one tab with a three-way view toggle: **List · Board · Budget**. Each view has its own mockup and carries the toggle.

| File | What it shows |
|---|---|
| **[plan-list.html](./plan-list.html)** | **The List view (default)** — the definitions library: grouped Ongoing / Payment plans / Planned purchases, each row editable, each carrying its footprint (what's left, next payment/date). Create lives here (`+ New`). |
| **[plan-detail.html](./plan-detail.html)** | **List drill-downs** — the sheets a row opens, each shown as a **desktop dialog + phone bottom sheet**. **Plan · Manage** (expanded: contents + `{date, amount}` schedule), **Plan · Edit** (header only, terms locked), **Ongoing · Edit** (amount, category, Repeats, Stop), and **Planned purchase · Edit** (amount, target month, optional deadline toggle, remove). |
| **[plan-board.html](./plan-board.html)** | **The Board view** — the try-on timeline. Drag a wishlist want onto a month to plan it; the month total shifts so you feel the weight; drag between months to reschedule. On phone the drag is real: on drag-start the months collapse to header rows and the wishlist to a cancel bar, so every month is a visible drop target. |
| **[plan-budget.html](./plan-budget.html)** | **The Budget view** — spending limit per category (sliders) + a monthly savings target, with a plain-arithmetic "Your month" readout (income − limits − target = free). The tracked-category list is **editable** (add/remove existing categories, no creation); untracked spend pools into an **Other** residual with no limit. The set-the-levers surface; Home does the live tracking. |
| **[plan-options.html](./plan-options.html)** | **Design history — the original comparison.** The three directions (A · library, B · horizon, C · dials) stacked side by side with rationale, from before Plan became one tab with three views. Kept to record why the three-view answer won; superseded by the three view files above. |

## The directions

The three directions live in [`plan-options.html`](./plan-options.html). Same axis we keep landing on: **object · time · money.**

| # | Direction | Answers | Signature | Distance from today's model |
|---|---|---|---|---|
| **A** | **The library** (object-first) | "What am I committed to?" | Grouped shelves — Ongoing / Payment plans / Planned purchases — each row carries its *footprint* (what's left, next due). Create lives here. | **Closest.** It's the literal missing screen; maps 1:1 to the objects. Risk: reads as "settings" if footprints are weak. |
| **B** | **The horizon** (time-first) | "When does it hurt?" | A forward run of months; each shows committed outflow as a bar, so a heavy month (Oct: tires land on the loan) reads at a glance. | **Boldest.** Novel and honest about *when* commitments bite; gives planned buys a natural home (a future month). Editing is one hop deeper. |
| **C** | **The dials** (money-first) | "What should this month add up to?" | Budget-per-category + savings target; a live *projected month* recomputes as you drag. The commitments feed it, read-only. | **Furthest.** Becomes the destination for Home's budget "Manage" link, but needs budgets + `MonthProjection` (not yet built) and is least about editing objects. |

## Decision & build order (ADR-0005)

Plan is one tab, three views (`List · Board · Budget`), built in that order:

1. **List** — the definitions library. The screen the model is asking for and the smallest honest build; buildable on today's data.
2. **Board** — the try-on timeline. Same data set as List, dragged across months. The read-only "committed horizon" is cheap; the full drag/try-on is gated on building the **Wishlist** (ADR-0022, unbuilt).
3. **Budget** — spending limits + savings target. The largest backend lift: neither budgets nor a target exist in the money service, and the live projection (`MonthProjection`, ADR-0007) is Accepted-but-unbuilt. The "Your month" readout is deliberately plain arithmetic, not that forecast, so the view can ship before ADR-0007 does.

## Notes from iteration

- **Payment-plan rows carry no fake cadence.** A plan is a set of explicit `{date, amount}` payments — sums vary, cadence can be anything ([ADR-0028](../../../../../services/money/docs/adr/0028-recurring-contents-at-root.md)). Rows show **what's left** as the headline + the **actual next payment** (`8 of 24 · next −$320 on Aug 3`), never "−$X per month."
- **The Board filters two axes.** The wishlist tray filters by **category chips** + **title search**; the months are scoped by a **year selector** (below). Phone carries the same controls in compact form.
- **Month window is derived, not paged.** No manual window pager. The current year shows **this month → December**; any future year shows **all twelve**. You only pick the **year** (`‹ 2026 ›`); columns scroll horizontally when the run is long. This replaced an earlier `4 of 12` pager that existed on desktop but had no mobile equivalent.
- **Planned single purchase = target period, no day.** A planned buy is filed to a **month**, not a date (ADR-0018) — the month *is* the schedule, which is why drag-to-a-column is the whole interaction. Only Payment-plan installments and Ongoing carry real dates; planned cards never show a day.
- **Wants carry a one-time / reusable flag.** `once` (fridge, tires) can be scheduled/bought a single time — dragging it out of the wishlist **removes** it from the tray; removing its planned purchase **returns** it; a move relocates the one instance (never duplicates — the move op takes extra care). `↻ reusable` (coffee, tea) **stays** in the tray and each drag spawns an independent planned purchase.
- **Phone collapses on drag.** Drag-start shrinks every month to a header row (name + balance) and the wishlist to a cancel bar; drop restores the shortened resting view. The earlier tap-a-want→tap-a-month picker was dropped — it read as "dragging a row into the list."
- **A plan opens Manage; only its header is editable.** Tapping a Payment-plan row opens **Manage** — read-only contents + the full payment schedule (paid/next status) — with just two write actions: `EditHeader` (name/category) and `Cancel` (refund / keep-paid). Its priceless contents and explicit `{date, amount}` payments are **locked** (ADR-0028/0029). An **Ongoing** row opens a full Edit (amount, category, `ChangeRule` Repeats block, Stop). These sheets render as a **centered dialog on desktop, a bottom sheet on phone**. Drawn in `plan-detail.html`.
- **Planned purchase: a month, or a deadline that implies one.** A single switch flips the input: **off** → pick the **target month** directly (what a wishlist drag sets); **on** → pick a **deadline date** and the month is **derived** from it. Either way it files to exactly one month — no month/date contradiction. **No deadline** → shown under the month, no date ("this month"); **with deadline** → a `by <date>` chip, sorted ahead of dateless buys, clay when near. Backend: a nullable `Deadline` — when set, the period is computed from it; when null, the period is chosen directly (ADR-0018 has neither today). Removing a wishlist-origin planned buy returns the want to the wishlist. Drawn in `plan-detail.html` (row 4) and `plan-list.html`.
- **A plan pays from the period, not an account.** Each installment comes out of the balance of the month it falls in — there's **no per-plan pay-from account**. Only an *extra / early* payment dips into a savings account, and that's chosen at pay-time, not on the plan. (Dropped the "Pay from" field from Plan · Edit.)
- **Wishlist items linked elsewhere (e.g. payment plans) — keep the links.** A wishlist item is a durable *want* with one **current commitment state**: `idle` (in the tray) → `planned` on a month (single purchase) **or** `financed` inside a payment plan (ADR-0028 `Line.WishlistItemId`) **or** `bought`. For a `once` want these are mutually exclusive, so a want that's financed by a plan simply **isn't in the try-on tray** — it's already spoken for, and it already shows on the board as **fixed weight** (its plan's installments feed each month's committed base). The board and the plan-create flow are two symmetric doors in/out of the tray (cancel a plan → want returns to `idle` → reappears in the tray, exactly like dragging it back). No double-scheduling, no double-count, no need to drop the links. `reusable` wants never hit this exclusivity and stay in the tray regardless.
- **Budget tracks an opt-in subset of categories.** The limit list is editable — add/remove which **existing** categories are tracked for budget compliance (no category *creation* here; that's a later feature). An untracked category isn't scored against a limit; its spend pools into a single **Other** residual bucket (no limit) in budget stats. So "budgeted" is a per-category flag, and Other is the catch-all.
- **No Save gate (decided — ADR-0005 §4).** A drag commits on drop — no staging layer, no unsaved-changes dialog. Placements are period-local plans (ADR-0018) with **no financial side effect** (nothing pays until you Buy on the active month), so they're fully reversible by dragging again; an **Undo** covers slips. A Save/apply model would fight the "least clicks, drop is the commit" thesis and the offline-outbox write path.
