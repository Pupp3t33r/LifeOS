using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;
using LifeOS.Money.Api.Domain.Recurring;

namespace LifeOS.Money.Api.Features.Recurring;

/// Request↔domain↔response mapping for the recurring feature. Request line amounts
/// are positive magnitudes; the direction sets the sign of the stored
/// <see cref="Line"/> (ADR-0026 signed lines), matching the flow-recording contract.
internal static class RecurringMapping
{
    public static FlowDirection ParseDirection(string direction) =>
        direction == "in" ? FlowDirection.In : FlowDirection.Out;

    public static string DirectionString(FlowDirection direction) =>
        direction == FlowDirection.In ? "in" : "out";

    public static string ModeString(ScheduleMode mode) =>
        mode == ScheduleMode.Live ? "live" : "materialized";

    public static string StatusString(RecurringStatus status) =>
        status == RecurringStatus.Active ? "active" : "cancelled";

    public static List<Line> ToLines(
        IReadOnlyList<RecurringLineRequest> lines, FlowDirection direction, string currency)
    {
        var sign = direction == FlowDirection.Out ? -1m : 1m;
        return lines
            .Select(x => new Line(x.Description, new CurrencyAmount(sign * x.Amount, currency), x.CategoryId))
            .ToList();
    }

    public static ScheduleLine ToScheduleLine(
        ScheduleLineRequest request, FlowDirection direction, string currency) =>
        new(request.LineId, request.DueDate, ToLines(request.Lines, direction, currency));

    public static RecurringResponse ToResponse(RecurringPayment recurring)
    {
        var estimated = recurring is { Mode: ScheduleMode.Live, EstimateLines.Count: > 0 }
            ? new CurrencyAmount(recurring.EstimateLines.Sum(x => x.Amount.Amount), recurring.Currency)
            : null;

        return new RecurringResponse(
            recurring.Id,
            recurring.OwnerId,
            recurring.Name,
            DirectionString(recurring.Direction),
            recurring.Currency,
            recurring.CategoryId,
            recurring.AccountId,
            ModeString(recurring.Mode),
            recurring.Rule,
            recurring.EstimateLines,
            estimated,
            recurring.ScheduleLines.Select(x => ToScheduleLineResponse(x, recurring.Currency)).ToList(),
            StatusString(recurring.Status),
            recurring.CreatedAt);
    }

    private static ScheduleLineResponse ToScheduleLineResponse(ScheduleLine line, string currency) =>
        new(line.LineId, line.DueDate, line.Lines, new CurrencyAmount(line.Total, currency));
}
