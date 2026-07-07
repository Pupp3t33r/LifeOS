using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.PlannedPurchases;

/// The result of adding or editing a planned purchase: the period it lives on, its
/// [EntryId], the signed [Lines], their Σ [Total], and the server timestamp.
public sealed record PlannedPurchaseWriteResponse(
    Guid PeriodId,
    Guid EntryId,
    IReadOnlyList<Line> Lines,
    CurrencyAmount Total,
    DateTimeOffset RecordedAt);
