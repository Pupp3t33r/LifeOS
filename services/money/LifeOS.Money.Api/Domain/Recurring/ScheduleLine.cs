using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Domain.Recurring;

/// One line of a Materialized schedule (ADR-0017/0019): a due date plus a line-item
/// breakdown (<see cref="Lines"/>, e.g. an all-in pre-order with shipping in payment
/// 1). <see cref="LineId"/> is the stable occurrence reference used as the back-ref
/// when the line is confirmed on the AccountingPeriod. The expected amount is the
/// signed Σ of <see cref="Lines"/> — see <see cref="Total"/>.
public sealed record ScheduleLine(Guid LineId, DateOnly DueDate, IReadOnlyList<Line> Lines)
{
    /// Signed total of the line-item breakdown, in the recurring payment's currency.
    public decimal Total => Lines.Sum(x => x.Amount.Amount);
}
