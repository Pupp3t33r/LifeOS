namespace LifeOS.Money.Api.Domain;

public sealed class DuplicateFlowException(Guid entryId)
    : Exception($"A flow entry with id '{entryId}' has already been recorded.")
{
    public Guid EntryId { get; } = entryId;
}
