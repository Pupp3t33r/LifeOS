# ADR-0030: External-domain linking and the wishlist creation contract

## Status

Accepted

Date: 2026-07-08

**Amends:**

- [ADR-0022](./0022-wishlist-items-packages-and-derived-status.md) — `WishlistItem.Estimate` becomes **optional** (a want may have no known price); adds the **external-link creation contract** (how a domain object becomes a wishlist item) and an **upsert idempotency** key `(OwnerId, ServiceType, ExternalId)` alongside the existing client-assigned-`Id` create path.

**Relates to:** [ADR-0024](./0024-category-model.md) (`Line.ExternalRef` — the transactional link carrier), [ADR-0010](./0010-asset-aggregate.md) / [ADR-0032](./0032-asset-lifecycle-event-sourced-ownership.md) (the Asset inherits the ref at formation), [ADR-0031](./0031-order-aggregate-ancillary-costs-and-receipt.md) (goods purchases), [ADR-0003](./0003-idempotency-via-client-assigned-uuids.md) (idempotency), [ADR-0002](./0002-event-versioning-strategy.md) (event versioning for the cross-service Kafka events), [ADR-0013](./0013-user-preferences-and-configurable-month.md) (non-event-sourced user state precedent). This ADR is the **first cross-domain Kafka event**, so it is the forcing function for the README **Deferred decisions** rows *CloudEvents envelope* and *Wolverine outbox conventions*. It sets only the minimal display `Name`; the full descriptor snapshot stays the deferred *`ExternalReference` snapshot caching* decision.

## Context

Phase 2 brings the first domain services (Board Games, Books). The intended flow — *user adds a board game in the Board Games app → it lands in their wishlist → they order it → it becomes an owned asset* — has no defined contract for the very first hop: **how a domain object enters Money's financial world.** Three sub-problems were never resolved:

1. **The chicken-and-egg.** You cannot wishlist a catalog entry that does not exist, so the catalog must be populated first; but the catalog cannot depend on Money (Money holds no descriptive data). Something has to create the catalog entry *and* the wishlist item together.
2. **Where the link lives.** Two prior ADRs each attached an external reference to a different object: `WishlistItem.ExternalRef` (ADR-0022, the desire side) and `Line.ExternalRef` (ADR-0024, the transaction side). Their relationship was never stated, so "can you link a purchase without a wishlist item?" had no answer.
3. **No-price wants.** A game auto-added from a domain app often has no MSRP. ADR-0022 typed `Estimate` as a required `CurrencyAmount`, which forbids the most common auto-add case.

Forces at play:

- Root `AGENTS.md` §2: Money owns financial state; the domain services own descriptive state (title, BGG id, cover, condition). Money must not duplicate it.
- **Money never calls other services** (README deferred *snapshot caching* row: "client-supplied snapshot at link time"). The linking contract must make Money a **passive party** — it may receive its own client's write, and it may **publish or consume Kafka events**, but it never synchronously calls another service or an external provider.
- **Kafka is the planned cross-service bus** (ADR-0002 governs event versioning; the README defers only the envelope and outbox conventions "until the first cross-domain event is wired"). This linking flow *is* that first cross-domain event. Pub/sub — not request/response — is how the two services stay in step, which also keeps the flow offline-tolerant and each service passive w.r.t. the other.
- The **external provider** (BoardGameGeek or equivalent) is the shared source of descriptive data; the **initiating client** looks it up. A client calling a public third-party API is not "Money calling a service" — Money the service is never in that path.
- ADR-0024 already carries `ExternalRef: ExternalReference?` on `Line` ("a direct specific-object link, decoupled from categorization"), so the money model *already* permits a purchase to reference a domain object with no wishlist item — e.g. ADR-0010's pre-existing import path.
- ADR-0003 idempotency (client-assigned UUIDs) and ADR-0013/0022's precedent (non-event-sourced documents for read-current user state).

## Decision

### The external link is one soft reference with two homes, by role

The link is `ExternalReference { ServiceType: string, ExternalId: Guid }` — an opaque cross-service pointer. It lives in two places, distinguished by role, never contradicting:

- **`WishlistItem.ExternalRef`** — the **desire** side (ADR-0022): "I want this domain object."
- **`Line.ExternalRef`** — the **transaction** side (ADR-0024): "this money bought that domain object."

Money stores only the opaque ref plus a **denormalized display `Name`** (so lists render without fanning out to the domain service). All richer descriptive state stays in the domain service; the full descriptor snapshot remains the deferred *snapshot caching* decision. The **Asset inherits the ref** at formation (ADR-0032), preferring `Line.ExternalRef`, falling back to the linked wishlist item's.

### Catalog independence and a symmetric, event-carried creation

The domain service owns its **catalog** (descriptive data), sourced from the external provider, independent of Money — and it owns the catalog **`ExternalId`**. A wishlist link can be created from **either app**, and the two services are reconciled by **Kafka events**, never synchronous cross-calls. Who mints the `ExternalId` differs by direction:

- **From the Board Games app** (the natural path): BG saves the catalog entry — **assigning the `ExternalId` on save** — then **publishes** a `DomainObjectWishlisted` event carrying the **short data + that saved id**, which **Money consumes** to create the wishlist item. No pre-assignment: BG saves, then forwards the saved id.
- **From the Wallet app:** to avoid a synchronous round-trip to BG (create the catalog entry → wait for its id → then save the want), the Wallet client **pre-assigns** the catalog `ExternalId` as a client-generated GUID — the same client-assigned-UUID pattern the platform already uses (ADR-0003). It writes the **short record** to Money as a wishlist item `{ ExternalRef, Name, Estimate? }` immediately, and the same id is delivered to BG to create the catalog entry (the detailed leg is BG's concern; see below). Pre-assignment is purely a round-trip-avoidance technique for this one direction.

**Money's commitment is deliberately minimal and symmetric: it deals only in the short link record** (`OwnerId`, `ExternalRef`, `Name`, `Estimate?`) it owns, and it reaches that record by exactly one of two triggers — **its own client's REST write** (Wallet-initiated) or **consuming a domain event** (BG-initiated). When a linked wishlist item is created via its client, Money **publishes** a lightweight `WishlistItemLinked` event so the domain service can react. Money **never holds or relays the detailed descriptive payload** — that travels on the domain service's own events / is fetched by the domain service from the provider. Whichever way the *detailed* catalog leg is wired is **out of scope for this Money ADR** (it belongs to the Board Games service, which does not yet exist); this ADR fixes only Money's short-record contract and its publish/consume events. The shared, pre-assigned `ExternalId` correlates both sides and makes each create idempotent. This dissolves the chicken-and-egg — wishlisting a domain good and seeding its catalog are the same act, propagated by event — without Money ever calling out.

### Wishlist upsert is idempotent on `(OwnerId, ServiceType, ExternalId)`

For the domain path, create-or-update is keyed on `(OwnerId, ServiceType, ExternalId)`, where `ExternalId` is BG's catalog id — **minted by BG on save** (BG-initiated) or **pre-assigned by the Wallet client to skip the round-trip** (Wallet-initiated). Because both the wishlist item and the domain catalog entry reference that same id, either side's create — a REST write **or** a consumed event, arriving in any order or more than once — is idempotent and cannot duplicate the want. This complements — does not replace — ADR-0022's client-assigned-`Id` create-idempotency, which still governs generic (non-domain) wants.

### `WishlistItem.Estimate` becomes optional

A want may carry **no** estimate (a domain auto-add with no MSRP; "I want this, no idea what it costs"). This is the *priceless-until-received* posture already established for materialized recurring contents (ADR-0029): a want's real cost is pinned later, from money actually paid (ADR-0031 receipt). Net-worth math is unaffected — a want is not an asset.

### Three creation doors, one carrier — and a domain policy on top of a permissive model

A wishlist item can be born three ways, all producing the same `ExternalRef` carrier:

1. **Consumed domain event** — Money consumes a `DomainObjectWishlisted` event published by a domain service (the Board-Games-app path: the user added the game there).
2. **Wallet-initiated** — the user searches the external provider inside Wallet, picks the object, and saves the want; Money stores the short wishlist item and **publishes** `WishlistItemLinked` so the domain service can seed its catalog. The client does the provider lookup; Money stays passive.
3. **Immediate purchase** — a goods `Line` carries `ExternalRef` directly (ADR-0024); a wishlist item is **not required by the model** to link or to form an asset.

Because the model already permits `Line.ExternalRef` with no wishlist item (door 3, and ADR-0010's import path), "no domain good without a wishlist item" is enforced as a **domain-flow policy** (the domain-fronted path always produces a wishlist item so the catalog association and derived status exist), **not** as a schema invariant. A plain expense — a line with neither `ExternalRef` nor `WishlistItemId` — mints nothing and forms no asset; the wishlist/asset machinery engages only for domain goods.

## Consequences

Positive:

- One coherent answer to "how does a domain object enter Money": a passive, idempotent, caller-supplied upsert, with the catalog populated in the same act.
- The chicken-and-egg is dissolved without Money ever calling another service.
- No-price wants are first-class; cost is pinned later from real money.
- The desire-side and transaction-side links are reconciled: same ref, two homes, Asset inherits it.

Negative:

- The two services are only **eventually** consistent on a new link (the counterpart record lands when its Kafka event is consumed). Accepted — a want is not balance-critical, and the pre-assigned `ExternalId` means a purchase or asset can reference the object even before the other side has caught up.
- Someone must fetch the **detailed** descriptive data from the external provider and deliver it to the Board Games service; that leg is deferred to the (not-yet-existing) BG service and its clients. Money is uninvolved, but the end-to-end flow is not fully specified by this ADR alone.
- Two idempotency keys coexist on wishlist creation (client `Id` for generic wants; `(Owner, ServiceType, ExternalId)` for domain goods). Bounded and role-separated.

Neutral:

- The denormalized `Name` is a minimal display snapshot; the fuller descriptor cache (thumbnail, metadata) stays the deferred *snapshot caching* decision.
- "No domain good un-wishlisted" is a flow policy; the schema deliberately stays permissive so the Asset import path and one-off domain purchases remain representable.

## Alternatives Considered

1. **Money synchronously fetches descriptive data (from the domain service or the external provider) at link time.** Rejected: violates "Money never calls other services." The initiating client does the provider lookup and supplies the short snapshot; the two services reconcile via Kafka events; Money only ever publishes/consumes.
2. **Synchronous REST upsert between the services (BG calls Money, or Money calls BG).** Rejected in favor of Kafka events: pub/sub decouples the two services, tolerates one being offline, keeps each passive w.r.t. the other, and matches the planned event bus (ADR-0002; the deferred envelope/outbox rows). A synchronous cross-call would couple availability and re-introduce "Money calls a service."
3. **The link lives only on the wishlist item; transactions never carry `ExternalRef`.** Rejected: contradicts ADR-0024 (which already put `ExternalRef` on `Line`) and would forbid the import path and one-off domain purchases. The link has two legitimate homes.
4. **Make the wishlist item a hard prerequisite for any domain purchase (schema invariant).** Rejected: over-couples the model; the import path (ADR-0010) creates owned domain assets that were never wanted. Enforce "always wishlisted" as a domain-flow policy instead.
5. **Keep `Estimate` required; default it to zero for no-MSRP adds.** Rejected: a stored `0` is a lie (it reads as "free"), and it pollutes any estimate-based rollup. Optional is honest; cost is pinned at receipt.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
