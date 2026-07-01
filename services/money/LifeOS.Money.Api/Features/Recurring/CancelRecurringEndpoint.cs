using LifeOS.Money.Api.Domain;
using Wolverine.Http;
using Wolverine.Marten;

namespace LifeOS.Money.Api.Features.Recurring;

public static class CancelRecurringEndpoint
{
    // Cancel (terminal, ADR-0017): future occurrences stop surfacing. An optional
    // reimbursement is a separate FlowRecorded(in) on the active period, not here.
    [WolverinePost("/recurring/{id}/cancel")]
    public static (RecurringResponse, Events) Handle(
        Guid id,
        HttpContext context,
        [WriteAggregate] RecurringPayment recurring)
    {
        RecurringGuards.RequireOwner(recurring, context);
        RecurringGuards.RequireActive(recurring);

        var cancelled = recurring.Cancel(DateTimeOffset.UtcNow);
        var view = recurring.Clone();
        view.Apply(cancelled);
        return (RecurringMapping.ToResponse(view), [cancelled]);
    }
}
