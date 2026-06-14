namespace LifeOS.Money.Api.Features.Transactions;

public sealed record RecordTransactionRequest(
    Guid TransactionId,
    decimal Amount,
    string Currency,
    string Description,
    DateTimeOffset OccurredAt);
