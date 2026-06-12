# Gateway Service — Agent Context

> **Parent:** [Root AGENTS.md](../../AGENTS.md)  
> **Depth:** Thin  
> **Stack:** .NET 10, YARP

## Service Identity

Gateway is the single entry point for all clients (web apps, mobile, admin). It handles:

- **Routing:** Path-based reverse proxy to backend services (`/api/money/*` → Money service).
- **Auth proxy:** JWT validation (Keycloak), passing `sub` claim downstream.
- **Composition:** BFF pattern — may compose multiple service calls for mobile/frontend needs.
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
| `/mobile/v1/*` | Gateway BFF composition |

## Anti-Patterns

- ❌ **Do not put business logic in the Gateway.** No domain rules, no calculations, no state mutations.
- ❌ **Do not call services synchronously for composition unless necessary.** Prefer async event-driven where possible.
- ❌ **Do not expose internal service ports directly.** All traffic goes through Gateway.
- ❌ **Do not hardcode service URLs.** Always use Aspire service discovery.

---

*Last updated: 2026-05-25*
