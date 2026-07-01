using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Recurring;
using LifeOS.Money.Api.Http;
using Wolverine.Http;
using Wolverine.Marten;

namespace LifeOS.Money.Api.Features.Recurring;

public static class RemoveScheduleLineEndpoint
{
    // Remove an unconfirmed Materialized line (ADR-0017). DEFERRED: the "unconfirmed
    // only" guard (reject removing a line already confirmed on a period) needs a
    // period-join at write time and is not enforced yet.
    [WolverineDelete("/recurring/{id}/schedule-lines/{lineId}")]
    public static (RecurringResponse, Events) Handle(
        Guid id,
        Guid lineId,
        HttpContext context,
        [WriteAggregate] RecurringPayment recurring)
    {
        RecurringGuards.RequireOwner(recurring, context);
        RecurringGuards.RequireActive(recurring);
        RecurringGuards.RequireMode(recurring, ScheduleMode.Materialized);

        if (!recurring.HasScheduleLine(lineId))
        {
            throw new NotFoundException($"Schedule line '{lineId}' was not found.");
        }

        var removed = recurring.RemoveScheduleLine(lineId);
        var view = recurring.Clone();
        view.Apply(removed);
        return (RecurringMapping.ToResponse(view), [removed]);
    }
}
