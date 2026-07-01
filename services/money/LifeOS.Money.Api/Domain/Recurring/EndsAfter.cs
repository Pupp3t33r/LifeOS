namespace LifeOS.Money.Api.Domain.Recurring;

/// A recurrence that stops after a fixed <see cref="Count"/> of occurrences, counted
/// from the first occurrence on or after the rule's Start (e.g. a 12-payment debt).
public sealed record EndsAfter(int Count) : RecurrenceEnd;
