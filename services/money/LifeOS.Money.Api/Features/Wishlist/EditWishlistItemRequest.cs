using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Wishlist;

/// Edits a wishlist want's desire fields in place (ADR-0022) — a full replace of the
/// user-authored state. The derived commitment status is untouched (it lives on a
/// separate projection, ADR-0034).
public sealed record EditWishlistItemRequest(
    string Recurrence,
    string? Name,
    string? Notes,
    CurrencyAmount? Estimate,
    Guid? PackageId,
    ExternalReference? ExternalRef,
    Guid? CategoryId = null,
    UnitDimension? DefaultUnitDimension = null);
