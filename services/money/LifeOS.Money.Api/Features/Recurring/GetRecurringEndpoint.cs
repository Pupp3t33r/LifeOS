using LifeOS.Money.Api.Domain;
using Wolverine.Http;
using Wolverine.Marten;

namespace LifeOS.Money.Api.Features.Recurring;

public static class GetRecurringEndpoint
{
    // One recurring payment by id (owner-scoped; another owner's is a 404).
    [WolverineGet("/recurring/{id}")]
    public static RecurringResponse Handle(
        Guid id,
        HttpContext context,
        [ReadAggregate] RecurringPayment recurring)
    {
        RecurringGuards.RequireOwner(recurring, context);
        return RecurringMapping.ToResponse(recurring);
    }
}
