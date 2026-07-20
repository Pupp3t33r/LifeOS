# Exchange rates — design mockups

Visual companion to **[Money ADR-0015](../../../../services/money/docs/adr/0015-fx-rate-sourcing-and-client-cache.md)** (FX rate sourcing + the client-facing Rates view). **Design references, not app code** — the shipped screen is built in Flutter (`lib/features/money/ui/rates/rates_screen.dart`) against the Calm tokens and the Money API (`GET /fx-rates/latest`). Where a mockup and the ADR disagree, the ADR wins.

## The file

| File | What it shows |
|---|---|
| **[rates.html](./rates.html)** | The **shipped v1** Exchange-rates view (desktop light + phone dark): every stored pair as `BASE → QUOTE`, the `1 X = Y Z` conversion, a **source chip** (Belarusbank sell preferred, Frankfurter fallback), the as-of date, and a **Stale** badge past the 2-day freshness threshold. Plus the **Home rail card** (extended) and a **v2 · curated & pinned** exploration. |

## Decisions reflected

- **Reached two ways** — from Settings → Money → **Exchange rates**, and from Home's **“Open rates ▸”** rail card. Phone has no rail, so phone reaches rates via Settings.
- **Currency filter (v1)** — a chip strip narrows the list to every pair containing a chosen currency, base *or* quote (“show me all my USD pairs”). Pure client-side view control over the already-fetched pairs — no backend, ships in v1.
- **Traceability is the whole point** (ADR-0015 no-false-precision): every row names its source and the date it applies to. Nothing in the app converts money without a rate the user can find here.
- **Source precedence** — one row per pair, Belarusbank (BYN-pivot card *sell*) preferred, Frankfurter fallback. Frankfurter already stores the full base×base matrix, so cross pairs (USD→EUR) are direct rows — no triangulation.
- **Change deltas dropped from the shipped card.** The earlier cockpit mock showed ▲/▼ .3% per pair; that needs a prior-day comparison the read model doesn’t compute. Deferred to **v2** with pinning.

## Deferred to v2 (shown, clearly labelled, outside the shipped frames)

- **Pin a pair** — a device-local favourite (star per pair, not per currency: “pin USD” is ambiguous, the filter already covers all-USD-pairs). Pinned pairs surface on the Home rail card.
- **Add a currency** — track one *outside* the server’s fetch set, which needs a per-user `TrackedCurrencies` preference unioned into `FxRateFetchService` (amends Money ADR-0015/0013). Tracked in [`PLAN.md` §13](../../../PLAN.md).
- **Change deltas** — vs. the previous stored date.

## Viewing

Self-contained (Calm palette inline; **Manrope** from Google Fonts per ADR-0007). `file://` is blocked by the font CDN, so serve the folder:

```bash
cd apps/wallet/docs/design/rates
python -m http.server 8000
# then open http://localhost:8000/rates.html
```
