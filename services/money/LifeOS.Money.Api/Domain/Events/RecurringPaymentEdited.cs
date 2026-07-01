namespace LifeOS.Money.Api.Domain.Events;

/// Header fields of a recurring payment changed (ADR-0017): name, category, and the
/// savings/source account context. The schedule (rule or lines) is edited via its own
/// events, not this one.
public sealed record RecurringPaymentEdited(
    Guid RecurringId,
    string Name,
    Guid? CategoryId,
    Guid? AccountId);
