using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Recurring;

/// One computed/listed occurrence in a window (ADR-0017). <see cref="OccurrenceRef"/>
/// is the stable key used when confirming/skipping on the AccountingPeriod: the due
/// date (ISO) for a Live occurrence, or the schedule LineId for a Materialized one.
/// Status (projected/paid/skipped) is added when period integration lands (Part B).
public sealed record OccurrenceResponse(
    DateOnly DueDate,
    string OccurrenceRef,
    CurrencyAmount ExpectedAmount,
    IReadOnlyList<Line> Lines);
