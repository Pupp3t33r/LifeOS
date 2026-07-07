# Table App — Architecture Decision Records

This folder holds architecture decisions specific to the **Table** Blazor Hybrid app — client-side concerns (UI, render modes, local storage, auth UX) that are not owned by any backend service. Server-side collection/catalog decisions live in the [Board Games ADR log](../../../../services/board-games/docs/adr/README.md); login/identity decisions live in the [Keycloak ADR log](../../../../aspire/LifeOS.AppHost/keycloak/docs/adr/README.md).

Each ADR is a single markdown file following the [Nygard format](https://adr.github.io). To start a new one, copy the format of an existing ADR here or [Board Games' `template.md`](../../../../services/board-games/docs/adr/template.md). Once an ADR is marked **Accepted**, its body is frozen — supersede via a new ADR, never edit.

## Accepted

| # | Title | Date |
|---|---|---|
| [0001](./0001-blazor-hybrid-stack.md) | Blazor Hybrid stack — MAUI (Android) + Blazor Web App (web) sharing an RCL; deliberate polyglot-frontend deviation from Flutter | 2026-07-07 |
| [0002](./0002-fluentui-and-custom-theme.md) | FluentUI Blazor + a board-games-specific theme (distinct from Calm) | 2026-07-07 |
| [0003](./0003-per-page-render-modes.md) | Per-page render modes — Static+EnhancedNav default; InteractiveServer for forms; WebAssembly deferred | 2026-07-07 |
| [0004](./0004-online-only-phase-1.md) | Online-only Phase 1 — no offline store/outbox; Dapper for any future read cache | 2026-07-07 |
| [0005](./0005-viewmodels-via-communitytoolkit-mvvm.md) | ViewModels via CommunityToolkit.Mvvm — shared across MAUI + Blazor hosts | 2026-07-07 |

## Related decisions housed elsewhere

| Where | Decision | Relevance |
|---|---|---|
| [Board Games ADR-0005](../../../../services/board-games/docs/adr/0005-host-guest-authorization.md) | Host/guest authorization (`Collection.HostUserId` + `ShareToken`) | Table is host-only in Phase 1; the guest seam is backend-ready. |
| [Root AGENTS.md](../../../../AGENTS.md) §3/§6 | Frontend stack + app templates | ADR-0001 amends the root frontend rule to acknowledge the polyglot frontend. |

## Numbering

ADRs here are numbered in acceptance order, **monotonic and never reused**, independent of every other ADR folder (this folder starts at 0001).
