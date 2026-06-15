namespace LifeOS.Money.Api.Domain.Events;

public sealed record TransactionRecorded(
    Guid AccountId,
    Guid TransactionId,
    CurrencyAmount Amount,
    string Description,
    DateTimeOffset OccurredAt,
    DateTimeOffset RecordedAt);
