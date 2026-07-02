using LifeOS.Money.Api.Domain;
using Wolverine.Http;
using Wolverine.Marten;

namespace LifeOS.Money.Api.Features.Recurring;

public static class CancelRecurringEndpoint
{
    // Cancel (terminal, ADR-0017): future occurrences stop surfacing. `?refunded=true`
    // records that a payment-plan cancellation carries a refund (ADR-0028 §6) — a
    // provisional flag pending the refund-flow design; the refund itself, when
    // applicable, is a separate FlowRecorded(in) on the active period, not here.
    [WolverinePost("/recurring/{id}/cancel")]
    public static (RecurringResponse, Events) Handle(
        Guid id,
        HttpContext context,
        [WriteAggregate] RecurringPayment recurring)
    {
        RecurringGuards.RequireOwner(recurring, context);
        RecurringGuards.RequireActive(recurring);

        var refunded = context.Request.Query["refunded"] == "true";
        var cancelled = recurring.Cancel(refunded, DateTimeOffset.UtcNow);
        var view = recurring.Clone();
        view.Apply(cancelled);
        return (RecurringMapping.ToResponse(view), [cancelled]);
    }
}
