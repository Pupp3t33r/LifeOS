using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Projections;

namespace LifeOS.Money.Api.Features.Wishlist;

/// One wishlist want as the Wallet reads it (ADR-0022/0034): the item document zipped
/// with its derived commitment status. A want with no status document reads as
/// <see cref="WishlistCommitment.Idle"/>. [PlannedYear]/[PlannedMonth] are set only when
/// Planned; [PlanId] only when Financed; [BoughtDate] only when Bought.
public sealed record WishlistItemResponse(
    Guid Id,
    WishlistRecurrence Recurrence,
    string? Name,
    string? Notes,
    CurrencyAmount? Estimate,
    Guid? PackageId,
    ExternalReference? ExternalRef,
    DateTimeOffset CreatedAt,
    WishlistCommitment Status,
    int? PlannedYear,
    int? PlannedMonth,
    Guid? PlanId,
    DateOnly? BoughtDate) {
    public static WishlistItemResponse From(WishlistItem item, WishlistItemStatus? status) =>
        new(item.Id,
            item.Recurrence,
            item.Name,
            item.Notes,
            item.Estimate,
            item.PackageId,
            item.ExternalRef,
            item.CreatedAt,
            status?.Status ?? WishlistCommitment.Idle,
            status?.PlannedYear,
            status?.PlannedMonth,
            status?.PlanId,
            status?.BoughtDate);
}
