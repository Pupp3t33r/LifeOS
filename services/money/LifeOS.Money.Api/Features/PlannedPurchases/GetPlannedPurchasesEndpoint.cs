using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Projections;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.PlannedPurchases;

public static class GetPlannedPurchasesEndpoint
{
    // The period's live planned purchases (ADR-0018), newest first — the "Planned"
    // half of the Home cockpit's Upcoming worklist, alongside recurring occurrences.
    // Owner-scoped. Cancelled entries are gone (their read rows were deleted); paid
    // ones are derived by joining the settling flow (its PlannedEntryId back-ref), so
    // the client can drop them from Upcoming the way it drops paid occurrences.
    [WolverineGet("/months/{year}/{month}/planned-purchases")]
    public static async Task<IReadOnlyList<PlannedPurchaseResponse>> Handle(
        int year,
        int month,
        HttpContext context,
        IQuerySession session)
    {
        var userId = context.GetUserId();

        var records = await session.Query<PlannedPurchaseRecord>()
            .Where(x => x.OwnerId == userId && x.Year == year && x.Month == month)
            .ToListAsync();

        var paidByPlanned = (await session.Query<FlowEntryRecord>()
                .Where(x => x.OwnerId == userId && x.Year == year && x.Month == month
                    && x.PlannedEntryId != null)
                .ToListAsync())
            .GroupBy(x => x.PlannedEntryId!.Value)
            .ToDictionary(x => x.Key, x => x.OrderByDescending(y => y.RecordedAt).First());

        return records
            .OrderByDescending(x => x.AddedAt)
            .Select(record =>
            {
                if (paidByPlanned.TryGetValue(record.Id, out var flow))
                {
                    return new PlannedPurchaseResponse(
                        record.Id, record.Lines, record.Total, record.Description, record.AddedAt,
                        "paid", flow.Total, DateOnly.FromDateTime(flow.OccurredAt.UtcDateTime));
                }

                return new PlannedPurchaseResponse(
                    record.Id, record.Lines, record.Total, record.Description, record.AddedAt,
                    "planned", null, null);
            })
            .ToList();
    }
}
