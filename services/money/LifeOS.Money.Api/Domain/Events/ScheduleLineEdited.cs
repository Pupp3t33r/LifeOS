using LifeOS.Money.Api.Domain.Recurring;

namespace LifeOS.Money.Api.Domain.Events;

/// An unconfirmed Materialized schedule line was edited (ADR-0017) — the honesty-valve
/// path for a debt reschedule (the user edits remaining lines to the lender's figures).
/// The line keeps its <see cref="ScheduleLine.LineId"/>.
public sealed record ScheduleLineEdited(Guid RecurringId, ScheduleLine Line);
