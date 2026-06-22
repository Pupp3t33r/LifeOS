# Gateway Service — Agent Context

> **Parent:** [Root AGENTS.md](../../AGENTS.md)  
> **Depth:** Thin  
> **Stack:** .NET 10, YARP

## Service Identity

Gateway is the single entry point for all clients (web apps, mobile, desktop, admin). It handles:

- **Routing:** Path-based reverse proxy to backend services (`/api/money/*` → Money service).
- **Auth proxy:** JWT validation (Keycloak), passing `sub` claim downstream.
- **Composition:** BFF pattern — may compose multiple service calls for app clients (the Wallet Flutter app targets Android, Web, Windows, and Linux from a single codebase, so BFF composition serves all of them).
- **Static hosting (Web):** Serves the Wallet Flutter web build as static files, same-origin as the API — no CORS. The AppHost passes the build path via `Wallet__WebRoot`; the Gateway guards on `Directory.Exists` so it starts fine even when the build is stale or missing.
- **Rate limiting / CORS:** Centralized at the edge.

### Wallet Web Hosting

The Gateway serves the Flutter web build from `apps/wallet/build/web/`. The flow:

1. Developer runs `flutter build web` in `apps/wallet/` (output → `build/web/`).
2. The AppHost passes the absolute build path as `Wallet__WebRoot` to the Gateway.
3. `Program.cs` registers `UseStaticFiles` + `UseDefaultFiles` with a `PhysicalFileProvider` pointing at the build root.
4. A SPA fallback (`MapFallback`) serves `index.html` for non-file paths (client-side routes like `/home`).
5. YARP API routes (`/api/*`, `/app/v1/*`) take precedence over the SPA fallback.

**Request resolution order:**

| Request | Resolved by |
|---|---|
| `/api/money/*` | YARP reverse proxy → Money service |
| `/flutter.js`, `/main.dart.js`, `/assets/*` | Static file middleware (Flutter build) |
| `/` | `index.html` (default files) |
| `/home`, `/transactions` (no extension) | SPA fallback → `index.html` |
| `/missing.js`, `/broken.png` (extension, not found) | 404 (not index.html) |

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

*Last updated: 2026-06-23*
