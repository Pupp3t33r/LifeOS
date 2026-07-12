using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Http;
using LifeOS.Money.Api.Projections;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Wishlist;

public static class GetWishlistScheduleEndpoint {
    // The schedule chips a want wears on the wishlist surface (ADR-0034 §Board horizon): a
    // read composition over the planned-purchase store with no new domain rules. Every
    // planned-purchase line referencing the want, in the forward window, is grouped by
    // (month, paid-state, unit-dimension) with the summed quantity — the "×0.5 kg" / "×2"
    // the chips show. Paid-state is joined from the settling flow (its PlannedEntryId
    // back-ref), mirroring GetAllPlannedPurchasesEndpoint. Optional fromYear/fromMonth
    // trims to a forward horizon (current+future); the client passes the current month.
    [WolverineGet("/wishlist/items/{id}/schedule")]
    public static async Task<IReadOnlyList<WishlistScheduleChipResponse>> Handle(
        Guid id,
        HttpContext context,
        IQuerySession session,
        int? fromYear = null,
        int? fromMonth = null) {
        var userId = context.GetUserId();

        var item = await session.LoadAsync<WishlistItem>(id);
        if (item is null || item.OwnerId != userId) {
            throw new NotFoundException($"Wishlist item '{id}' was not found.");
        }

        var records = await session.Query<PlannedPurchaseRecord>()
            .Where(x => x.OwnerId == userId)
            .ToListAsync();

        if (fromYear is int fy && fromMonth is int fm) {
            var floor = fy * 12 + (fm - 1);
            records = records.Where(x => x.Year * 12 + (x.Month - 1) >= floor).ToList();
        }

        var paidEntryIds = (await session.Query<FlowEntryRecord>()
                .Where(x => x.OwnerId == userId && x.PlannedEntryId != null)
                .ToListAsync())
            .Select(x => x.PlannedEntryId!.Value)
            .ToHashSet();

        return records
            .SelectMany(record => record.Lines
                .Where(line => line.WishlistItemId == id)
                .Select(line => new {
                    record.Year,
                    record.Month,
                    Paid = paidEntryIds.Contains(record.Id),
                    UnitDimension = line.UnitDimension ?? UnitDimension.Pieces,
                    Quantity = line.Quantity ?? 1m,
                }))
            .GroupBy(x => new { x.Year, x.Month, x.Paid, x.UnitDimension })
            .OrderBy(g => g.Key.Year).ThenBy(g => g.Key.Month)
            .Select(g => new WishlistScheduleChipResponse(
                g.Key.Year, g.Key.Month, g.Key.Paid, g.Key.UnitDimension, g.Sum(x => x.Quantity)))
            .ToList();
    }
}
