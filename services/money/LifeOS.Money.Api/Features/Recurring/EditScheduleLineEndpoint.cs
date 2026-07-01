using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Recurring;
using LifeOS.Money.Api.Http;
using Wolverine.Http;
using Wolverine.Marten;

namespace LifeOS.Money.Api.Features.Recurring;

public static class EditScheduleLineEndpoint
{
    // Edit an unconfirmed Materialized line in place (ADR-0017) — the debt-reschedule
    // honesty valve. The route LineId is authoritative (the body's is ignored). The
    // "unconfirmed only" guard against the AccountingPeriod lands with Part B.
    [WolverinePut("/recurring/{id}/schedule-lines/{lineId}")]
    public static (RecurringResponse, Events) Handle(
        Guid id,
        Guid lineId,
        ScheduleLineRequest request,
        HttpContext context,
        [WriteAggregate] RecurringPayment recurring)
    {
        RecurringGuards.RequireOwner(recurring, context);
        RecurringGuards.RequireActive(recurring);
        RecurringGuards.RequireMode(recurring, ScheduleMode.Materialized);
        AddScheduleLineEndpoint.ValidateLines(request with { LineId = lineId });

        if (!recurring.HasScheduleLine(lineId))
        {
            throw new NotFoundException($"Schedule line '{lineId}' was not found.");
        }

        var line = RecurringMapping.ToScheduleLine(
            request with { LineId = lineId }, recurring.Direction, recurring.Currency);
        var edited = recurring.EditScheduleLine(line);
        var view = recurring.Clone();
        view.Apply(edited);
        return (RecurringMapping.ToResponse(view), [edited]);
    }
}
