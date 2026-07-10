namespace LifeOS.Money.Api.Features.PlannedPurchases;

/// One line of a planned purchase as the client sends it: a positive [Amount]
/// magnitude (a planned purchase is always spending, so the server signs it negative),
/// an optional budgeting [CategoryId] (ADR-0024), an optional [Description], and an
/// optional [WishlistItemId] linking the line to a wishlist want (ADR-0034 — the ref a
/// Board drag carries so the want reads as Planned).
public sealed record PlannedPurchaseLine(
    decimal Amount,
    Guid? CategoryId,
    string? Description,
    Guid? WishlistItemId = null);
