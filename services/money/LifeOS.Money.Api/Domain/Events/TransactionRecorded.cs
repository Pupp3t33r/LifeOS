namespace LifeOS.Money.Api.Domain.Events;

public sealed record TransactionRecorded(
    Guid AccountId,
    Guid TransactionId,
    decimal Amount,
    string Currency,
    string Description,
    DateTimeOffset OccurredAt,
    DateTimeOffset RecordedAt);
