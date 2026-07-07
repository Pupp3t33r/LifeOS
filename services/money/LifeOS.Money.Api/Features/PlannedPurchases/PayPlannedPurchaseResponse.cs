using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.PlannedPurchases;

/// The flow recorded by paying a planned purchase: which period it landed in, the new
/// flow's [EntryId], the [PlannedEntryId] it settles, its signed [Total], and the
/// timestamps. The planned purchase now reads as <c>paid</c> in that period.
public sealed record PayPlannedPurchaseResponse(
    Guid PeriodId,
    Guid EntryId,
    Guid PlannedEntryId,
    CurrencyAmount Total,
    DateTimeOffset OccurredAt,
    DateTimeOffset RecordedAt);
