using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Wishlist;

/// Creates a wishlist want (ADR-0022/0034). [Id] is client-assigned for idempotency
/// (ADR-0003). [Estimate] is optional (ADR-0030 — a want may have no known price).
/// [Recurrence] is the once/reusable keystone (ADR-0034) as a wire string
/// ("once" | "reusable"). [ExternalRef] links a domain object (e.g. board-games/{bggId});
/// [PackageId] groups it under a package.
public sealed record CreateWishlistItemRequest(
    Guid Id,
    string Recurrence,
    string? Name,
    string? Notes,
    CurrencyAmount? Estimate,
    Guid? PackageId,
    ExternalReference? ExternalRef);
