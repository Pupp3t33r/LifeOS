# Gateway Service — Agent Context

> **Parent:** [Root AGENTS.md](../../AGENTS.md)  
> **Depth:** Thin  
> **Stack:** .NET 10, YARP

## Service Identity

Gateway is the single entry point for all clients (web apps, mobile, desktop, admin). It handles:

- **Routing:** Path-based reverse proxy to backend services (`/api/money/*` → Money service).
- **Auth proxy:** JWT validation (Keycloak), passing `sub` claim downstream.
- **Composition:** BFF pattern — may compose multiple service calls for app clients (the Wallet Flutter app targets Android, Web, Windows, and Linux from a single codebase, so BFF composition serves all of them).
- **Rate limiting / CORS:** Centralized at the edge.

## Tech Stack

- **Reverse Proxy:** YARP (Yet Another Reverse Proxy)
- **Auth:** JWT Bearer validation against Keycloak
- **Configuration:** `appsettings.json` for routes, code for cluster destinations (Aspire service discovery)

## YARP Routing Conventions

Routes are defined in `appsettings.json`:

```json
{
  "ReverseProxy": {
    "Routes": {
      "money": {
        "ClusterId": "money",
        "Match": {
          "Path": "/api/money/{**catch-all}"
        },
        "Transforms": [
          {
            "PathPattern": "{**catch-all}"
          }
        ]
      }
    }
  }
}
```

Cluster destinations are resolved in `Program.cs` from Aspire service discovery:

```csharp
var moneyUrl = builder.Configuration["services:money:http:0"]
    ?? builder.Configuration["services:money:https:0"]
    ?? "http://localhost:5221";
```

### Path Prefix Rules

| Prefix | Destination Service |
|---|---|
| `/api/money/*` | Money |
| `/api/books/*` | Books |
| `/api/board-games/*` | Board Games |
| `/api/steam/*` | Steam |
| `/api/media/*` | Media |
| `/api/planner/*` | Planner |
| `/app/v1/*` | Gateway BFF composition |

> **Note:** The BFF prefix is `/app/v1/*` (renamed from `/mobile/v1/*` on 2026-06-15). The Wallet Flutter app is multi-platform (Android, Web, Windows, Linux), not mobile-only, so the prefix reflects all app clients. BFF endpoints compose data across services for app consumption (e.g., `GET /app/v1/inventory` enriches Money Asset rows with descriptive data from Books/Board Games per `apps/wallet/PLAN.md`).

## Anti-Patterns

- ❌ **Do not put business logic in the Gateway.** No domain rules, no calculations, no state mutations.
- ❌ **Do not call services synchronously for composition unless necessary.** Prefer async event-driven where possible.
- ❌ **Do not expose internal service ports directly.** All traffic goes through Gateway.
- ❌ **Do not hardcode service URLs.** Always use Aspire service discovery.

---

*Last updated: 2026-06-15*
