using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Recurring;

public static class ListRecurringEndpoint
{
    // All of the caller's recurring payments (active and cancelled), by name. The
    // read model is the inline aggregate snapshot, queried as a document.
    [WolverineGet("/recurring")]
    public static async Task<IReadOnlyList<RecurringResponse>> Handle(
        HttpContext context,
        IQuerySession session)
    {
        var userId = context.GetUserId();

        var items = await session.Query<RecurringPayment>()
            .Where(x => x.OwnerId == userId)
            .ToListAsync();

        return items
            .OrderBy(x => x.Name)
            .Select(RecurringMapping.ToResponse)
            .ToList();
    }
}
