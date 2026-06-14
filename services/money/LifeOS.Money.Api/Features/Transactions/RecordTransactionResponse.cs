namespace LifeOS.Money.Api.Features.Transactions;

public sealed record RecordTransactionResponse(
    Guid AccountId,
    Guid TransactionId,
    decimal Amount,
    string Currency,
    string Description,
    DateTimeOffset OccurredAt,
    DateTimeOffset RecordedAt,
    decimal NewBalanceForCurrency);
