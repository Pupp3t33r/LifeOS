namespace LifeOS.Money.Api.Domain.Recurring;

/// The two schedule modes of a <see cref="RecurringPayment"/> (ADR-0017).
public enum ScheduleMode
{
    /// A recurrence <see cref="RecurrenceRule"/>; occurrences are computed, never
    /// stored. Salary, rent, subscriptions.
    Live,

    /// A finite, editable list of <see cref="ScheduleLine"/>s with known due dates
    /// and amounts. Debt, installments, pre-orders (collapses the old InstallmentPlan).
    Materialized,
}
