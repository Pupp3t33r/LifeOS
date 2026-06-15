using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Accounts;

public sealed record AccountResponse(
    Guid AccountId,
    string OwnerId,
    string Name,
    CurrencyAmount Balance,
    string Currency,
    DateTimeOffset OpenedAt);
