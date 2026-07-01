namespace LifeOS.Money.Api.Features.Recurring;

/// Skip a recurring occurrence (ADR-0017): unpaid, no arrears. The occurrence is
/// resolved as skipped in its due-date period.
public sealed record SkipOccurrenceRequest(string OccurrenceRef);
