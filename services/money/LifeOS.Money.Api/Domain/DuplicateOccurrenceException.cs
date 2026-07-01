namespace LifeOS.Money.Api.Domain;

/// An occurrence was already confirmed or skipped in its period (ADR-0017's
/// within-period idempotency: an occurrence maps to exactly one period by its date,
/// so this is a local check, not a cross-period scan).
public sealed class DuplicateOccurrenceException(RecurringReference occurrence)
    : Exception($"Occurrence '{occurrence.ToKey()}' is already confirmed or skipped in this period.")
{
    public RecurringReference Occurrence { get; } = occurrence;
}
