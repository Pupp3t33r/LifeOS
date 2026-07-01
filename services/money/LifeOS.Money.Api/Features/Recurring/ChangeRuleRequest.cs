using LifeOS.Money.Api.Domain.Recurring;

namespace LifeOS.Money.Api.Features.Recurring;

/// Replace a Live recurring payment's rule (ADR-0017, forward-only in-place edit).
public sealed record ChangeRuleRequest(RecurrenceRule Rule);
