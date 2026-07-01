namespace LifeOS.Money.Api.Domain.Recurring;

/// An open-ended recurrence — salary, rent, a subscription (ADR-0017).
public sealed record NeverEnds : RecurrenceEnd;
