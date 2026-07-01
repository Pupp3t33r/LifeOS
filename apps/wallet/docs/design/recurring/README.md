# Recurring — design mockups

Static HTML mockups for the **recurring payments & income** feature (backend is built and green — see `services/money/PLAN.md` §3.2 and Money ADRs [0017 recurring](../../../../../services/money/docs/adr/0017-recurring-payment-rules-and-schedules.md) / [0016 flow ledger](../../../../../services/money/docs/adr/0016-accounting-period-flow-ledger.md)). These explore the *front-of-house*: where the feature lives in the app and how you resolve a due item. **First pass — for discussion, not frozen.**

These are **design references, not app code.** The real screens are built in Flutter against the Calm tokens (`lib/app/theme/calm_tokens.dart`) and the Money API. Where a mockup and the ADRs/backend disagree, the backend wins.

## Viewing

Each file is self-contained (Calm palette inline as CSS variables; Bricolage Grotesque + Spline Sans from Google Fonts). `file://` is blocked by the font CDN, so serve the folder:

```bash
cd apps/wallet/docs/design/recurring
python -m http.server 8000
# then open http://localhost:8000/recurring-options.html
```

## The files

Everything lives on/around **Home** — the Plan tab is out of scope for now. The worklist reuses the vocabulary already set in [`../home/cockpit-final.html`](../home/cockpit-final.html): the Upcoming/Logged split, the checkbox, "Mark paid," and "due Jul 1" as a plain date label. There is **no separate "due" colour or icon** — an item is simply unticked (Upcoming) or ticked (Logged). Creation opens from the Home FAB, which now offers three separate verbs: **Add** · **Ongoing** · **Payment plan**.

| File | What it shows |
|---|---|
| **[recurring-options.html](./recurring-options.html)** | **On the worklist.** Recurring items appear as Upcoming rows with a checkbox + "Mark paid"; income uses the same row with a + amount; a confirmed item drops to Logged (showing `planned −$200` struck through only when the real amount differed). Desktop + phone. |
| **[resolve.html](./resolve.html)** | **Marking paid — two paths.** *Paid as planned*: one tap on the row's "Mark paid," no sheet. *Different real amount*: tap the row body → the sheet opens pre-filled to the plan, overwrite the figure (−$180 vs planned −$200), confirm. No "just this month" warning; the plan-vs-real cue is a faint strikethrough shown only on divergence. |
| **[create-ongoing.html](./create-ongoing.html)** | **Creation sheet 1 · the `Live` kind (Ongoing) — every state.** The add-entry sheet + one **Repeats** block. All interactions: empty → filled → multiline; the Every / On / Ends pickers (Ends is only *never* / *on a date*); the income variant. No count, no schedule — a countable end is a Payment plan instead. |
| **[create-payment-plan.html](./create-payment-plan.html)** | **Creation sheet 2 · the `Materialized` kind (Payment plan) — every state.** A plan = **one financed purchase**: an **item list at the root** (what you bought — real categories) **+ payments that are just `{date, amount}`**, every item financed by the whole schedule. One rule: *payments sum to items*. States: empty → items → payments (balanced) → off-balance (blocked, "split evenly") → add-payment (pre-fill) → ready. Upfront extras (sleeves, shipping) are **separate entries**, reunited later by an **ADR-0022 Package**. Structure + confirm = **[ADR-0028](../../../../../services/money/docs/adr/0028-recurring-contents-at-root.md)** (Accepted). |
| **[create-sentence-parked.html](./create-sentence-parked.html)** | **Parked, reference only.** The fill-in-the-blank sentence builder — set aside in favour of the classic form, kept in case it returns as a "quick add" mode. |

## The model these render (backend, already built)

- A recurring item holds an **expected** amount. Each period it produces an **occurrence**: `projected` → `paid` or `skipped`.
- **Confirm** records a real flow on the period the actual date maps to, carrying a back-reference so the occurrence reads `paid`. The confirm can **override the amount** — so `ActualAmount` may differ from `ExpectedAmount` (both retained; the plan is untouched). This is the utilities −$200 → −$180 case.
- **Skip** marks the occurrence resolved with no flow. Confirm/skip are user-driven — nothing auto-posts. Double-resolving the same occurrence is a 409.
- Two schedule shapes, now two named kinds: `Live` rule-computed = **Ongoing**; `Materialized` = **Payment plan**. Users never see the internal mode names, nor the word "recurring."
- **Payment plan restructured (ADR-0028, Accepted):** a plan is *one financed purchase* — items at the **root**, payments bare `{date, amount}`, Σ balance. This makes "what did I buy" first-class; confirming a payment records a **proportional slice** of the items (budgets exact). Upfront extras and shared shipping are **separate entries**, not items — grouping, "what's in the box," and order status reuse the *existing* **ADR-0022** (Wishlist items + Packages + derived status) via `Line.WishlistItemId`, not a new entity. Supersedes the per-payment `ScheduleLine.Lines` of 0017/0019.

## What changed after the first review

- **Plan tab dropped** — everything is on Home for now.
- **No "due" state** — reused the cockpit checkbox + Upcoming/Logged split; "due Jul 1" is only a date.
- **Create = two named kinds, two separate FAB options** (no chooser): **Add** · **Ongoing** · **Payment plan**. Each opens its own dedicated sheet. Naming the kinds up front replaces the hidden `Live`↔`Materialized` mode-switch that "Ends → after N" used to smuggle in; uneven payments are only ever a Payment plan. Multiline like normal entries; expense/income a toggle inside.
- **The word "recurring" is dropped from the UI** — it stays only as the internal/folder name and the backend `RecurringPayment` type. User-facing: *Ongoing*, *Payment plan*, *Mark paid*, *Skip*.
- **Payment plan has no count / no auto-even** — you add each payment with **+**; each + pre-fills from the previous (next month, same amount) for fast even plans, and any payment is individually editable and multiline.
- **Mark paid = one tap, no sheet**; the sheet appears only to log a different real amount. Removed the "just this month" warning; plan-vs-real kept to a faint strikethrough on divergence.

## Open threads (to settle in review)

1. **Skip** — the one gesture not yet drawn. Options: inside the sheet (as now), a swipe on the row, or a row overflow menu.
2. ~~Name for the `Live` kind~~ — **settled: Ongoing** (pairs with Payment plan; covers income + expense).
3. ~~Payment-plan restructure & ledger categories~~ — **settled: [ADR-0028](../../../../../services/money/docs/adr/0028-recurring-contents-at-root.md) (Accepted, amends 0017/0019)** — items at the aggregate root, payments money-only, Σ balance, confirm = **A · proportional slice**. Grouping / status reuse **ADR-0022** via `Line.WishlistItemId`. Implementation pending. "In route + ETA" is the one genuinely-future bit.
4. **Plan-vs-real cue** — keep the faint `planned −$200` strikethrough on divergence, or drop it entirely (real number alone).
5. **Copy** — user-facing words only; the word *recurring* is out. Never *Live / Materialized / Occurrence / Flow*.
