namespace LifeOS.Money.Api.Features.Accounts;

public sealed record OpenAccountRequest(
    Guid AccountId,
    string Name,
    string Currency,
    decimal? OpeningBalanceAmount);
