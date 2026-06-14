namespace LifeOS.Money.Api.Domain;

public sealed class DuplicateTransactionException(Guid transactionId)
    : Exception($"A transaction with id '{transactionId}' has already been recorded.")
{
    public Guid TransactionId { get; } = transactionId;
}
