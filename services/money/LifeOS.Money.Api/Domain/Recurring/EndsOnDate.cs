namespace LifeOS.Money.Api.Domain.Recurring;

/// A recurrence that stops after a fixed date (inclusive): occurrences due on or
/// before <see cref="Date"/> fire; later ones do not.
public sealed record EndsOnDate(DateOnly Date) : RecurrenceEnd;
