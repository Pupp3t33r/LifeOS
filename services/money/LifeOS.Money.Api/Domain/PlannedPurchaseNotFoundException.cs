namespace LifeOS.Money.Api.Domain;

/// The referenced planned purchase does not exist in this period — edit/cancel/pay of
/// an unknown entry (mapped to 404).
public sealed class PlannedPurchaseNotFoundException(Guid entryId)
    : Exception($"A planned purchase with id '{entryId}' was not found in this period.")
{
    public Guid EntryId { get; } = entryId;
}
