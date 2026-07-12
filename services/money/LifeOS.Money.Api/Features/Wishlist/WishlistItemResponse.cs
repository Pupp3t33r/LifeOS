using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Projections;

namespace LifeOS.Money.Api.Features.Wishlist;

/// One wishlist want as the Wallet reads it (ADR-0022/0034): the item document zipped
/// with its derived commitment status. A want with no status document reads as
/// <see cref="WishlistCommitment.Idle"/>. [PlannedYear]/[PlannedMonth] are set only when
/// Planned; [PlanId] only when Financed; [BoughtDate] only when Bought. [CategoryId] +
/// [DefaultUnitDimension] (ADR-0036) are the want's user category and default quantity unit.
public sealed record WishlistItemResponse(
    Guid Id,
    string Recurrence,
    string? Name,
    string? Notes,
    CurrencyAmount? Estimate,
    Guid? PackageId,
    ExternalReference? ExternalRef,
    DateTimeOffset CreatedAt,
    string Status,
    int? PlannedYear,
    int? PlannedMonth,
    Guid? PlanId,
    DateOnly? BoughtDate,
    Guid? CategoryId,
    UnitDimension? DefaultUnitDimension) {
    public static WishlistItemResponse From(WishlistItem item, WishlistItemStatus? status) =>
        new(item.Id,
            WishlistMapping.RecurrenceString(item.Recurrence),
            item.Name,
            item.Notes,
            item.Estimate,
            item.PackageId,
            item.ExternalRef,
            item.CreatedAt,
            WishlistMapping.CommitmentString(status?.Status ?? WishlistCommitment.Idle),
            status?.PlannedYear,
            status?.PlannedMonth,
            status?.PlanId,
            status?.BoughtDate,
            item.CategoryId,
            item.DefaultUnitDimension);
}
