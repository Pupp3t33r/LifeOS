using LifeOS.Money.Api.Domain.Events;

namespace LifeOS.Money.Api.Domain;

public sealed partial class Account
{
    public Guid Id { get; set; }
    public string OwnerId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public DateTimeOffset OpenedAt { get; set; }
    public Dictionary<string, decimal> Balances { get; set; } = new();
    public HashSet<Guid> RecordedTransactionIds { get; set; } = new();

    public static AccountOpened Open(Guid id, string ownerId, string name, DateTimeOffset openedAt)
    {
        return new AccountOpened(id, ownerId, name, openedAt);
    }

    public TransactionRecorded RecordTransaction(
        Guid transactionId,
        decimal amount,
        string currency,
        string description,
        DateTimeOffset occurredAt,
        DateTimeOffset recordedAt)
    {
        if (amount == 0)
        {
            throw new ArgumentException("Amount must be non-zero.", nameof(amount));
        }

        if (RecordedTransactionIds.Contains(transactionId))
        {
            throw new DuplicateTransactionException(transactionId);
        }

        return new TransactionRecorded(
            Id,
            transactionId,
            amount,
            currency,
            description,
            occurredAt,
            recordedAt);
    }

    public void Apply(AccountOpened @event)
    {
        Id = @event.AccountId;
        OwnerId = @event.OwnerId;
        Name = @event.Name;
        OpenedAt = @event.OpenedAt;
    }

    public void Apply(TransactionRecorded @event)
    {
        Balances[@event.Currency] = Balances.GetValueOrDefault(@event.Currency) + @event.Amount;
        RecordedTransactionIds.Add(@event.TransactionId);
    }
}
