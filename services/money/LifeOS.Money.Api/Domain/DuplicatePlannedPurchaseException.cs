namespace LifeOS.Money.Api.Domain;

public sealed class DuplicatePlannedPurchaseException(Guid entryId)
    : Exception($"A planned purchase with id '{entryId}' has already been added.")
{
    public Guid EntryId { get; } = entryId;
}
