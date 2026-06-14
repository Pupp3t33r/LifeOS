namespace LifeOS.Money.Api.Features.Accounts;

public sealed record AccountResponse(
    Guid AccountId,
    string OwnerId,
    string Name,
    IReadOnlyDictionary<string, decimal> Balances,
    DateTimeOffset OpenedAt);
