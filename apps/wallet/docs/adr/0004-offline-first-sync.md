# ADR-0004: Offline-first sync — cached read models, a write outbox, and idempotent replay

## Status

Proposed

Date: 2026-06-30

**Relates to:** [Money ADR-0003](../../../../services/money/docs/adr/0003-idempotency-via-client-assigned-uuids.md) (client-assigned ids — the cornerstone that makes blind replay safe), [Money ADR-0016](../../../../services/money/docs/adr/0016-accounting-period-flow-ledger.md) (the period flow ledger — the first read model cached this way), [Money ADR-0007](../../../../services/money/docs/adr/0007-monthly-review-and-projection.md) (`MonthProjection` — the composed read model this generalizes to), [Wallet ADR-0002](./0002-navigation-and-information-architecture.md) (the current-period cockpit that consumes the cache). Supersedes the informal offline-first description in `apps/wallet/AGENTS.md` §"Data and sync" — once Accepted, AGENTS points here.

## Context

The Wallet is a personal-finance client for a solo user on a phone, desktop, and web, on a network that is sometimes absent. It must stay usable offline — read recent state, log an expense — and reconcile when the network returns, without ever corrupting the server's books or showing a number the server didn't compute.

The Money service is the **single source of truth** for all financial state (root `AGENTS.md`, `apps/wallet/AGENTS.md`). Money's domain rules are event-sourced server-side; the client must not re-implement them. So the client's job is narrow: cache what the server says for offline reading, queue mutations durably so they survive an app kill and an offline gap, and replay them safely.

The base shape (read models + outbox + idempotency) has lived informally in `AGENTS.md` since the project's start but was never frozen. The period-flows cache slice (2026-06-30) implemented it for real and forced several concrete choices — what the local store holds, whether the online path differs from the offline one, how optimistic UI works, how stale a cache may get, and how failures are classified. This ADR freezes those.

Forces at play:

- **Offline reads must always work.** A cockpit that blanks without a network is useless on a train. Reads come from a local cache, never directly from the network at render time.
- **A queued mutation must survive everything** — app kill, OS eviction, days offline — and must never apply twice. Money ADR-0003's client-assigned ids make a duplicate a no-op (409 = already applied), which is what makes "retry after an uncertain send" safe.
- **No client-side domain logic.** No client aggregates, projections, or event log. The cache is a *copy of the server's read-model response*, not state the client derives from events.
- **One code path is simpler than two.** A write path that branches on connectivity ("POST now if online, else queue") has two failure surfaces and a race at the boundary (network drops mid-POST). A single always-queue path has one.
- **Solo user, modest data.** No multi-user conflict resolution; financial history is small. This lets retention and sync be simple.

## Decision

### 1. The local store holds exactly two things

A single local drift database (`lib/app/data/`) holds:

1. **Cached read models** — local mirrors of server read-model responses (the period flow ledger today; `MonthProjection`, account balances, etc. as they land). Read-through caches, never an event log.
2. **A write outbox** (`pending_operations`) — queued HTTP mutations, each carrying a client-assigned idempotency id (Money ADR-0003) and a status.

No client-side aggregates, projections, or event log. **Money's business rules run once, on the server.**

### 2. Writes always go through the outbox — online and offline alike

A mutation is **always** enqueued to the outbox first; the UI returns the moment that local row commits (that write *is* the "saved before the server" guarantee). A drainer replays queued rows to Money; the call never blocks the UI on the network.

This **resolves** the previously-stated "when online, POST immediately" rule in favour of **one uniform path**. The online case is not special-cased: there is a single write surface, a single retry mechanism, and no mid-POST connectivity race. (This also pairs naturally with the operations-log direction — see Deferred.)

### 3. Replay is idempotent; failures are classified

The drainer replays `method`/`path`/`payload` **verbatim** — no client validation, no payload transformation. Per outcome:

- **2xx** → `synced`.
- **409 Conflict** → `synced`. The server already has this client-assigned id (Money ADR-0003), so the op is effectively applied; a blind replay after an uncertain earlier send is therefore safe.
- **other 4xx** (400/403/404/422…) → `failed`. A request the user must fix; replaying it unchanged cannot succeed. Surfaced to the user.
- **401/408/429, any 5xx, or no response** (offline/DNS/timeout) → left `pending` for the next drain. Transient.

### 4. Reads are stale-while-revalidate

A screen renders from the cache **immediately** and revalidates in the background: fetch the relevant read model, rewrite its cached rows in one transaction, and **swallow network errors** so the existing cache stands for offline reads. There is no TTL — revalidation is eager (on screen open and on outbox change). A per-read-model "last synced" timestamp is surfaced so the user can see freshness.

### 5. Optimistic UI is an outbox overlay, not a cache write

A just-added (or offline) mutation appears instantly by **decoding the pending outbox op and overlaying it** onto the rendered view, marked as syncing — **deduped by the client-assigned id** once the confirmed row arrives via revalidation. The cache itself holds **only server-confirmed truth**; provisional state never enters it, so there is nothing to "un-apply" if a write ultimately fails. (This refines AGENTS' "apply optimistically to cached read models" toward an overlay model.)

### 6. Cache retention: keep everything (no eviction in v1)

A cached read model retains every period/entity ever fetched, with no eviction. The data is tiny (a flow entry is a few hundred bytes) and past periods are immutable once closed (Money ADR-0007/0023), so stale history cannot drift. A rolling-window eviction is a later refinement only if multi-year accounts make a table large.

## Consequences

Positive:

- Offline reads and writes both work; a queued write survives kill/offline and applies exactly once (idempotency).
- One write path means one failure surface and no connectivity-boundary race.
- The cache can never hold unconfirmed state, so there is no client-side reconciliation/rollback logic.
- The client adds nothing to Money's domain surface — it mirrors responses and replays requests.

Negative:

- **Sync flicker.** Because the cache is updated by a *revalidation GET* (not from the mutation's response), a just-synced entry can blink: its op leaves the optimistic overlay (status → `synced`) a beat before the revalidate lands the confirmed row. Sub-second for a solo user. Removing it fully needs a response-aware drain (see Deferred).
- **Eager revalidation is chatty.** Refetching on every screen open + outbox change has no TTL. Fine against a solo user's own gateway; a throttle is a cheap later addition.
- **Replay is not instant on reconnect.** Without connectivity-driven drain (see Deferred), a queued op replays on the next trigger (launch/sign-in/after-enqueue), not the instant the network returns.

Neutral:

- The freshness timestamp is computed at render, not on a timer, so a long-idle screen can show a slightly stale "Updated …". Eager revalidation makes this rare.
- Client money values currently round-trip through `double`; the decimal-safe representation arrives with the generated OpenAPI client (Phase 5). Display-only until then.

## Deferred sub-decisions (captured, non-blocking)

- **Operations log instead of a drain queue.** Evolve `pending_operations` from a transient queue (synced rows retired) into a **durable log of all operations — complete and pending — showing only pending by default**: an audit/history of every change, a real answer to "what did I do while offline?", and a clean pair with the uniform-queue path (§2). Deferred until a history/activity surface or audit need forces the schema (retain + status filter + a retention/pruning policy). Today's drainer still retires synced rows.
- **Response-aware drain (kill the flicker).** Have the drain write the confirmed row from the mutation's 2xx response instead of waiting for a revalidation GET. Removes the §-Consequences flicker but couples the generic drainer to per-feature response shapes. Deferred; the generic drainer (with sub-second flicker) stands for now.
- **Connectivity-driven auto-drain** (`connectivity_plus`) — drain the instant the network returns, not just on the next trigger. Deferred.
- **Revalidation throttle / TTL** — bound eager refetching if it proves noisy. Deferred.
- **Cache eviction (rolling window)** — only if multi-year data makes keep-everything heavy. Deferred.

## Alternatives Considered

1. **Branch the write path on connectivity** ("POST immediately when online, else queue"). Rejected: two code paths, two failure surfaces, and a race when the network drops mid-POST. The uniform always-queue path is simpler and strictly safer given idempotency.
2. **Optimistically write provisional rows into the cache, reconcile later.** Rejected: the cache would hold unconfirmed state needing a tag-and-clean reconciliation and rollback-on-failure. The outbox overlay achieves instant UI while keeping the cache pure-server.
3. **Update the cache from each mutation's response (no revalidation GET).** This is the response-aware drain; it removes the flicker but couples the generic drainer to feature response shapes. Deferred rather than rejected — a likely future refinement.
4. **Client-side projection/event-log (full local replica).** Rejected hard: re-implements Money's domain on the client, the exact thing the architecture forbids; enormous surface for the client and server to disagree.
5. **No cache — fetch on every view.** Rejected: breaks offline reads entirely and makes the UI network-bound.
6. **TTL-based cache invalidation.** Rejected for v1 in favour of eager revalidation (simpler, and cheap for a solo user); a TTL/throttle is captured as a deferred refinement.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
