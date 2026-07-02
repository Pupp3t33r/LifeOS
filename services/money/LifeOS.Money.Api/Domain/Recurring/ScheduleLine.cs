namespace LifeOS.Money.Api.Domain.Recurring;

/// One scheduled payment of a Materialized plan (ADR-0017, restructured by ADR-0028):
/// a due date and a **bare money** amount — a *when-and-how-much*, nothing more. The
/// plan's line-item *contents* live once on the aggregate root (<see cref="Domain.RecurringPayment.Items"/>);
/// a payment is a portion of that whole, and confirming one records a proportional
/// slice of the items (ADR-0028 §4). <see cref="LineId"/> is the stable occurrence
/// reference used as the back-ref when the payment is confirmed on the AccountingPeriod.
/// <see cref="Amount"/> is signed (negative = out) in the plan's currency.
public sealed record ScheduleLine(Guid LineId, DateOnly DueDate, CurrencyAmount Amount);
