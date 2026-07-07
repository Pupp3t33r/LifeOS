using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.PlannedPurchases;

/// One planned purchase as the cockpit reads it (ADR-0018). Line [Amount]s are signed
/// negative (spending); [Total] is their Σ. [Status] is "planned" or "paid" — paid is
/// derived by joining the settling flow, whose actual [PaidTotal] and [PaidOn] are then
/// populated (they may differ from the planned [Total] if the amount was adjusted).
public sealed record PlannedPurchaseResponse(
    Guid EntryId,
    IReadOnlyList<Line> Lines,
    CurrencyAmount Total,
    string? Description,
    DateTimeOffset AddedAt,
    string Status,
    CurrencyAmount? PaidTotal,
    DateOnly? PaidOn);
