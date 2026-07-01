namespace LifeOS.Money.Api.Domain.Recurring;

/// Lifecycle of a <see cref="RecurringPayment"/> (ADR-0017). "Completed" is a derived
/// display state (all lines confirmed/skipped, or a Live rule reached its end), not an
/// authoritative status — so it is not represented here.
public enum RecurringStatus
{
    Active,
    Cancelled,
}
