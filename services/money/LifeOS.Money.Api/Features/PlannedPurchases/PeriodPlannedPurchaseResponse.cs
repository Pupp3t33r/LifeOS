using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.PlannedPurchases;

/// A planned purchase carrying its period (ADR-0018/0034) — the cross-period shape the
/// Plan List and Board read, unlike the period-scoped <see cref="PlannedPurchaseResponse"/>.
public sealed record PeriodPlannedPurchaseResponse(
    Guid EntryId,
    int Year,
    int Month,
    IReadOnlyList<Line> Lines,
    CurrencyAmount Total,
    string? Description,
    DateTimeOffset AddedAt,
    string Status,
    CurrencyAmount? PaidTotal,
    DateOnly? PaidOn,
    DateOnly? Deadline);
