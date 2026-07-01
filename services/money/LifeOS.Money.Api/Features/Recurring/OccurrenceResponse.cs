using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Recurring;

/// One computed/listed occurrence in a window (ADR-0017). <see cref="OccurrenceRef"/>
/// is the stable key used when confirming/skipping on the AccountingPeriod: the due
/// date (ISO) for a Live occurrence, or the schedule LineId for a Materialized one.
///
/// <see cref="Status"/> is derived by joining the occurrence against the period's
/// back-references: <c>projected</c> (unresolved), <c>paid</c> (a confirming
/// <c>FlowRecorded</c> exists — <see cref="ActualAmount"/>/<see cref="PaidOn"/> carry
/// the real figures, which may differ from <see cref="ExpectedAmount"/>), or
/// <c>skipped</c>.
public sealed record OccurrenceResponse(
    DateOnly DueDate,
    string OccurrenceRef,
    CurrencyAmount ExpectedAmount,
    IReadOnlyList<Line> Lines,
    string Status,
    CurrencyAmount? ActualAmount,
    DateOnly? PaidOn);
