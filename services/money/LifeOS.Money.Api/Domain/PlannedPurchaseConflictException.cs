namespace LifeOS.Money.Api.Domain;

/// A planned purchase can no longer be edited, cancelled, or paid because it is in a
/// terminal state (already cancelled or already paid) — mapped to 409.
public sealed class PlannedPurchaseConflictException(Guid entryId, string reason)
    : Exception($"Planned purchase '{entryId}' cannot be modified: {reason}.")
{
    public Guid EntryId { get; } = entryId;
}
