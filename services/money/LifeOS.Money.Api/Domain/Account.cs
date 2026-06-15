using LifeOS.Money.Api.Domain.Events;

namespace LifeOS.Money.Api.Domain;

public sealed partial class Account
{
    public Guid Id { get; set; }
    public string OwnerId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Currency { get; set; } = string.Empty;
    public CurrencyAmount Balance { get; set; } = new(0, string.Empty);
    public DateTimeOffset OpenedAt { get; set; }
    public HashSet<Guid> RecordedTransactionIds { get; set; } = new();

    public static AccountOpened Open(
        Guid id,
        string ownerId,
        string name,
        string currency,
        CurrencyAmount? openingBalance = null,
        DateTimeOffset? openedAt = null)
    {
        var balance = openingBalance ?? new CurrencyAmount(0, currency);
        return new AccountOpened(id, ownerId, name, currency, balance, openedAt ?? DateTimeOffset.UtcNow);
    }

    public TransactionRecorded RecordTransaction(
        Guid transactionId,
        CurrencyAmount amount,
        string description,
        DateTimeOffset occurredAt,
        DateTimeOffset recordedAt)
    {
        if (amount.Amount == 0)
        {
            throw new ArgumentException("Amount must be non-zero.", nameof(amount));
        }

        if (amount.Currency != Currency)
        {
            throw new InvalidOperationException(
                $"Transaction currency '{amount.Currency}' does not match account currency '{Currency}'.");
        }

        if (RecordedTransactionIds.Contains(transactionId))
        {
            throw new DuplicateTransactionException(transactionId);
        }

        return new TransactionRecorded(
            Id,
            transactionId,
            amount,
            description,
            occurredAt,
            recordedAt);
    }

    public void Apply(AccountOpened @event)
    {
        Id = @event.AccountId;
        OwnerId = @event.OwnerId;
        Name = @event.Name;
        Currency = @event.Currency;
        Balance = @event.OpeningBalance;
        OpenedAt = @event.OpenedAt;
    }

    public void Apply(TransactionRecorded @event)
    {
        Balance = new CurrencyAmount(Balance.Amount + @event.Amount.Amount, Currency);
        RecordedTransactionIds.Add(@event.TransactionId);
    }
}
