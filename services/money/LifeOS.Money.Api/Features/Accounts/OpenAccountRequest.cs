namespace LifeOS.Money.Api.Features.Accounts;

public sealed record OpenAccountRequest(Guid AccountId, string Name);
