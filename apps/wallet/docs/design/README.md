# Wallet — design mockups

Static HTML mockups for the Wallet app's surfaces. **Design references, not app code** — the real screens are built in Flutter against the Calm tokens (`lib/app/theme/calm_tokens.dart`) and the Money API. Each set has its own README recording the decisions and ADR references for that surface.

## Sets

| Set | Surface | README |
|---|---|---|
| **[home](./home/)** | The monthly savings cockpit (Home) — canvas, budgets, rows. | [README](./home/README.md) |
| **[plan](./plan/)** | The Plan destination — List · Board · Budget. | [README](./plan/README.md) |
| **[recurring](./recurring/)** | Create & resolve Ongoing and Payment-plan flows. | [README](./recurring/README.md) |
| **[wishlist](./wishlist/)** | The wants backlog — the management surface. | [README](./wishlist/README.md) |
| **[rates](./rates/)** | The Exchange-rates view — traceable FX rates + sources (ADR-0015). | [README](./rates/README.md) |
| **[settings](./settings/)** | The searchable, grouped Settings page + Categories. | — |

## Convention — frames ship only what's real

A mockup's device frame contains **only shipping UI**. Reviewer-facing legends, color/stage keys, reference tables, and explanatory footnotes belong **outside the frame** (the dark masthead/notes above it, or the `.label`/`.rowhd` captions between frames) or in the set's README — never inside the frame. If a design needs an in-frame legend to be understood, it isn't self-evident enough: **fix the design, don't annotate it.** This holds across every set (home · plan · recurring · wishlist) and is mirrored in [`../AGENTS.md`](../AGENTS.md).

## Viewing

Each mockup is self-contained (Calm palette inline; Bricolage Grotesque + Spline Sans from Google Fonts). `file://` is blocked by the font CDN, so serve a folder:

```bash
cd apps/wallet/docs/design/<set>
python -m http.server 8000
# then open http://localhost:8000/<file>.html
```
