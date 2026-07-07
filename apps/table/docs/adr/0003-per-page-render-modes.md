# ADR-0003: Per-page render modes — Static+EnhancedNav default; InteractiveServer for forms; WebAssembly deferred

## Status

Accepted

Date: 2026-07-07

**Relates to:** [ADR-0001](./0001-blazor-hybrid-stack.md) (the RCL + two-host shape that makes this possible).

## Context

Modern Blazor (.NET 8+; this project is .NET 10) offers several render modes for the **web host**, and the choice can be made per page/component rather than globally:

- **Static SSR** — server renders HTML once per request; no interactivity, no Blazor JS runtime for the page.
- **InteractiveServer** — runs on the server; UI updates sent as DOM diffs over a SignalR WebSocket.
- **InteractiveWebAssembly** — runs entirely in-browser via WASM; offline-capable, heavy initial download.
- **InteractiveAuto** — Server first (fast first paint), swaps to WASM once cached.

Two related techniques layer on top:

- **Enhanced Navigation** (on by default via the tiny `blazor.web.js`, *not* the full WASM runtime) — pages stay Static SSR but navigation between them fetches the new HTML and morphs the diff into the DOM, giving SPA-like feel (preserved scroll, no full reload) with zero WASM download.
- **Enhanced Forms** — form submits go via `fetch`, response diffed in, no full reload.

Table's pages fall into two broad categories: read-heavy (collection list, catalog search, game detail, guest read-only view) and interactive (add-to-collection form, sleeve editor, accessory-binding UI). The read-heavy pages don't need a persistent WebSocket or a WASM download; the interactive ones need some client-side execution but not offline.

Forces at play:

- The cheapest mode that works per page keeps the client footprint small and first paint fast.
- Table is online-only in Phase 1 (ADR-0004), so WebAssembly's offline capability is unused — its cost (download, complexity) buys nothing yet.
- The shared RCL must stay render-mode-agnostic so the MAUI host (which ignores render modes) and the Web host (which assigns them) share the same components.

## Decision

The Web host assigns a **render mode per page/route**, with **Static SSR + Enhanced Navigation as the default** for read-heavy pages:

| Page kind | Mode | Why |
|---|---|---|
| Collection list, catalog search results, game detail, guest read-only | **Static SSR + Enhanced Navigation** | Cheapest; smooth SPA-like navigation via DOM-diff; no WASM, no WebSocket; SEO-friendly |
| Add-to-collection form, sleeve editor, accessory-binding UI | **InteractiveServer** (`@rendermode InteractiveServer`) | Light interactivity; small client footprint; no big download |
| (Future) offline play-logging at a cafe | **InteractiveWebAssembly** | Deferred — only if offline becomes a real requirement |

**Prerendering** stays on by default for the interactive modes (fast first paint, SEO), hydrating after.

**Host-agnostic discipline (hard rule):** the RCL components **must not** declare a render mode or call host-specific APIs directly. JS interop differs between Server and WebAssembly; `HttpClient` base URL differs between MAUI and Web. Host-provided services sit behind interfaces (`IApiClient`, `IPlatformInfo`) resolved per host. The Web host applies render modes at the `RouteView`/`@rendermode` level; the MAUI host runs everything natively.

## Consequences

Positive:

- Read-heavy pages (the bulk of a collection manager) get the smallest possible client footprint and fast first paint.
- Interactive pages get real interactivity without a WASM download.
- Per-page choice means no global lock-in — a page can move up the spectrum (Static → Server → WebAssembly) as needs evolve.
- The RCL stays genuinely shared across MAUI and Web because components are mode-agnostic.

Negative:

- Two techniques to keep straight (render modes vs Enhanced Navigation) — the latter is a layer on Static, not a mode itself. Documented here to avoid confusion.
- Host-agnostic discipline is a real constraint: a component that accidentally hardcodes `IJSRuntime`-only logic or a render mode breaks one host. Mitigated by the hard rule + host-service interfaces.

Neutral:

- `blazor.web.js` (Enhanced Navigation) is a small script, not the WASM runtime — it loads even on Static pages. Negligible.

## Alternatives Considered

1. **Global InteractiveServer for the whole web app.** Rejected: a persistent WebSocket for read-only catalog/detail pages is wasteful; Static + Enhanced Nav is strictly cheaper for those.
2. **Global InteractiveWebAssembly.** Rejected: Table is online-only in Phase 1 (ADR-0004); WASM's offline capability is unused, and the download cost is unjustified. Also the old "locked into WebAssembly if sharing with Hybrid" concern — resolved by .NET 8+'s render-mode system, but the cost/benefit still favours Server for the interactive pages.
3. **InteractiveAuto everywhere.** Rejected: Auto's WASM-cache benefit only pays off for pages visited repeatedly with offline need; for an online-only Phase 1 it adds complexity without payoff.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
