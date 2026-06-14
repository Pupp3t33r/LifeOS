namespace LifeOS.Money.Api.Domain.Events;

public sealed record AccountOpened(
    Guid AccountId,
    string OwnerId,
    string Name,
    DateTimeOffset OpenedAt);
