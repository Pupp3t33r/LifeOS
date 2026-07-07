namespace LifeOS.Money.Api.Features.Recurring;

/// A Materialized plan item as the client authors it (ADR-0029): priceless contents.
/// <see cref="ReferenceValue"/> is an optional positive magnitude (MSRP-style,
/// informational only — never validated against or summed with the payments); when set
/// it is stored in the plan's currency. <see cref="CategoryId"/> is the budgeting
/// category and <see cref="WishlistItemId"/> the Phase-2 link (ADR-0019/0022).
public sealed record PlanItemRequest(
    string? Description,
    decimal? ReferenceValue,
    Guid? CategoryId,
    Guid? WishlistItemId);
