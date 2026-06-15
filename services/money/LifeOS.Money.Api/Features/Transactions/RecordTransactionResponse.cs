using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Transactions;

public sealed record RecordTransactionResponse(
    Guid AccountId,
    Guid TransactionId,
    CurrencyAmount Amount,
    string Description,
    DateTimeOffset OccurredAt,
    DateTimeOffset RecordedAt,
    CurrencyAmount NewBalance);
