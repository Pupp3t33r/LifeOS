using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;

namespace LifeOS.Money.Tests.Domain;

public class AccountRecordTransactionTests
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
            account.RecordTransaction(
                Guid.NewGuid(),
                new CurrencyAmount(0m, "EUR"),
                "x",
                DateTimeOffset.UtcNow,
                DateTimeOffset.UtcNow));
    }

    [Fact]
    public void RejectsCurrencyMismatch()
    {
        var account = NewAccount("EUR");
        Assert.Throws<InvalidOperationException>(() =>
            account.RecordTransaction(
                Guid.NewGuid(),
                new CurrencyAmount(10m, "USD"),
                "x",
                DateTimeOffset.UtcNow,
                DateTimeOffset.UtcNow));
    }

    [Fact]
    public void RejectsDuplicateTransactionId()
    {
        var account = NewAccount();
        var txId = Guid.NewGuid();
        var recorded = account.RecordTransaction(
            txId,
            new CurrencyAmount(-10m, "EUR"),
            "first",
            DateTimeOffset.UtcNow,
            DateTimeOffset.UtcNow);
        account.Apply(recorded);

        Assert.Throws<DuplicateTransactionException>(() =>
            account.RecordTransaction(
                txId,
                new CurrencyAmount(-10m, "EUR"),
                "duplicate",
                DateTimeOffset.UtcNow,
                DateTimeOffset.UtcNow));
    }

    [Fact]
    public void ReturnsTransactionRecorded_WithExpectedPayload()
    {
        var account = NewAccount();
        var txId = Guid.NewGuid();
        var occurredAt = DateTimeOffset.UtcNow;
        var recordedAt = DateTimeOffset.UtcNow.AddSeconds(1);

        var recorded = account.RecordTransaction(
            txId,
            new CurrencyAmount(-25m, "EUR"),
            "Groceries",
            occurredAt,
            recordedAt);

        Assert.Equal(account.Id, recorded.AccountId);
        Assert.Equal(txId, recorded.TransactionId);
        Assert.Equal("Groceries", recorded.Description);
        Assert.Equal(occurredAt, recorded.OccurredAt);
        Assert.Equal(recordedAt, recorded.RecordedAt);
    }
}
