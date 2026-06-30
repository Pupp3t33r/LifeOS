using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;

namespace LifeOS.Money.Tests.Domain;

public class AccountRecordSavingsMovementTests
{
    private static Account NewAccount(string currency = "EUR") =>
        AccountFromOpened(Account.Open(Guid.NewGuid(), "owner-1", "Test", currency, new CurrencyAmount(100m, currency)));

    private static Account AccountFromOpened(AccountOpened opened)
    {
        var account = new Account();
        account.Apply(opened);
        return account;
    }

    [Fact]
    public void RejectsZeroAmount()
    {
        var account = NewAccount();
        Assert.Throws<ArgumentException>(() =>
            account.RecordSavingsMovement(
                Guid.NewGuid(),
                new CurrencyAmount(0m, "EUR"),
                DateTimeOffset.UtcNow,
                DateTimeOffset.UtcNow,
                MovementSource.Manual,
                "x"));
    }

    [Fact]
    public void RejectsCurrencyMismatch()
    {
        var account = NewAccount("EUR");
        Assert.Throws<InvalidOperationException>(() =>
            account.RecordSavingsMovement(
                Guid.NewGuid(),
                new CurrencyAmount(10m, "USD"),
                DateTimeOffset.UtcNow,
                DateTimeOffset.UtcNow,
                MovementSource.Manual,
                "x"));
    }

    [Fact]
    public void RejectsDuplicateMovementId()
    {
        var account = NewAccount();
        var movementId = Guid.NewGuid();
        var recorded = account.RecordSavingsMovement(
            movementId,
            new CurrencyAmount(-10m, "EUR"),
            DateTimeOffset.UtcNow,
            DateTimeOffset.UtcNow,
            MovementSource.Manual,
            "first");
        account.Apply(recorded);

        Assert.Throws<DuplicateMovementException>(() =>
            account.RecordSavingsMovement(
                movementId,
                new CurrencyAmount(-10m, "EUR"),
                DateTimeOffset.UtcNow,
                DateTimeOffset.UtcNow,
                MovementSource.Manual,
                "duplicate"));
    }

    [Fact]
    public void ReturnsSavingsMovementRecorded_WithExpectedPayload()
    {
        var account = NewAccount();
        var movementId = Guid.NewGuid();
        var occurredAt = DateTimeOffset.UtcNow;
        var recordedAt = DateTimeOffset.UtcNow.AddSeconds(1);

        var recorded = account.RecordSavingsMovement(
            movementId,
            new CurrencyAmount(-25m, "EUR"),
            occurredAt,
            recordedAt,
            MovementSource.Manual,
            "Manual withdrawal");

        Assert.Equal(account.Id, recorded.AccountId);
        Assert.Equal(movementId, recorded.MovementId);
        Assert.Equal(MovementSource.Manual, recorded.Source);
        Assert.Equal("Manual withdrawal", recorded.Description);
        Assert.Equal(occurredAt, recorded.OccurredAt);
        Assert.Equal(recordedAt, recorded.RecordedAt);
    }
}
