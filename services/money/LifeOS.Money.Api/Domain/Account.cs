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
    public HashSet<Guid> RecordedMovementIds { get; set; } = new();

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

    public SavingsMovementRecorded RecordSavingsMovement(
        Guid movementId,
        CurrencyAmount amount,
        DateTimeOffset occurredAt,
        DateTimeOffset recordedAt,
        MovementSource source,
        string? description = null,
        Guid? transferId = null,
        decimal? fxRate = null)
    {
        if (amount.Amount == 0)
        {
            throw new ArgumentException("Amount must be non-zero.", nameof(amount));
        }

        if (amount.Currency != Currency)
        {
            throw new InvalidOperationException(
                $"Movement currency '{amount.Currency}' does not match account currency '{Currency}'.");
        }

        if (RecordedMovementIds.Contains(movementId))
        {
            throw new DuplicateMovementException(movementId);
        }

        return new SavingsMovementRecorded(
            Id,
            movementId,
            amount,
            source,
            occurredAt,
            recordedAt,
            description,
            transferId,
            fxRate);
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

    public void Apply(SavingsMovementRecorded @event)
    {
        Balance = new CurrencyAmount(Balance.Amount + @event.Amount.Amount, Currency);
        RecordedMovementIds.Add(@event.MovementId);
    }
}
