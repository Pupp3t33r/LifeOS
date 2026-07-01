using LifeOS.Money.Api.Domain.Recurring;

namespace LifeOS.Money.Api.Domain.Events;

/// A Live recurrence rule was edited in place (ADR-0017), forward-only: occurrences
/// due on/after the new rule use it; confirmed actuals on the ledger are immutable and
/// unaffected. Full rule history is recoverable by replaying this stream.
public sealed record RuleChanged(Guid RecurringId, RecurrenceRule Rule, DateTimeOffset ChangedAt);
