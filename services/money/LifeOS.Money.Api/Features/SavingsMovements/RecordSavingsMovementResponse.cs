using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;

namespace LifeOS.Money.Api.Features.SavingsMovements;

public sealed record RecordSavingsMovementResponse(
    Guid AccountId,
    Guid MovementId,
    CurrencyAmount Amount,
    MovementSource Source,
    string? Description,
    DateTimeOffset OccurredAt,
    DateTimeOffset RecordedAt,
    CurrencyAmount NewBalance);
