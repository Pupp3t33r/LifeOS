namespace LifeOS.Money.Api.Features.Wishlist;

/// Creates a wishlist package (ADR-0022) — a named grouping. [Id] is client-assigned for
/// idempotency (ADR-0003).
public sealed record CreatePackageRequest(Guid Id, string Name);
