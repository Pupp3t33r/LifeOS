using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Projections;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.PlannedPurchases;

public static class GetAllPlannedPurchasesEndpoint {
    // Cross-period planned purchases for the Plan List "Planned purchases" shelf and the
    // Board timeline (ADR-0005 / ADR-0034) — the period-agnostic view that per-period
    // GET /months/{y}/{m}/planned-purchases cannot give. Owner-scoped; a read composition
    // over the PlannedPurchaseRecord read-model with no new domain rules. Optional
    // fromYear/fromMonth trims to a forward horizon; paid status is joined from the
    // settling flow, so the client can style/drop paid entries as on the cockpit.
    [WolverineGet("/planned-purchases")]
    public static async Task<IReadOnlyList<PeriodPlannedPurchaseResponse>> Handle(
        HttpContext context,
        IQuerySession session,
        int? fromYear = null,
        int? fromMonth = null) {
        var userId = context.GetUserId();

        var records = await session.Query<PlannedPurchaseRecord>()
            .Where(x => x.OwnerId == userId)
            .ToListAsync();

        if (fromYear is int fy && fromMonth is int fm) {
            var floor = fy * 12 + (fm - 1);
            records = records.Where(x => x.Year * 12 + (x.Month - 1) >= floor).ToList();
        }

        var paidByPlanned = (await session.Query<FlowEntryRecord>()
                .Where(x => x.OwnerId == userId && x.PlannedEntryId != null)
                .ToListAsync())
            .GroupBy(x => x.PlannedEntryId!.Value)
            .ToDictionary(x => x.Key, x => x.OrderByDescending(y => y.RecordedAt).First());

        return records
            .OrderBy(x => x.Year).ThenBy(x => x.Month).ThenByDescending(x => x.AddedAt)
            .Select(record => {
                var (status, paidTotal, paidOn) = paidByPlanned.TryGetValue(record.Id, out var flow)
                    ? ("paid", (Domain.CurrencyAmount?)flow.Total,
                        (DateOnly?)DateOnly.FromDateTime(flow.OccurredAt.UtcDateTime))
                    : ("planned", null, null);
                return new PeriodPlannedPurchaseResponse(
                    record.Id, record.Year, record.Month, record.Lines, record.Total,
                    record.Description, record.AddedAt, status, paidTotal, paidOn, record.Deadline);
            })
            .ToList();
    }
}
