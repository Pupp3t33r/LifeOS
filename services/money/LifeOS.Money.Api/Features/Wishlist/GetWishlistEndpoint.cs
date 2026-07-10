using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Projections;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Wishlist;

public static class GetWishlistEndpoint {
    [WolverineGet("/wishlist")]
    public static async Task<WishlistResponse> Handle(
        HttpContext context,
        IQuerySession session) {
        var userId = context.GetUserId();

        var items = await session.Query<WishlistItem>()
            .Where(x => x.OwnerId == userId)
            .ToListAsync();
        var packages = await session.Query<Package>()
            .Where(x => x.OwnerId == userId)
            .ToListAsync();

        // Zip each item with its derived status doc (ADR-0022): one bulk load, no per-item
        // round-trip. A missing status doc → Idle (WishlistItemResponse.From handles null).
        var statuses = items.Count == 0
            ? []
            : (await session.LoadManyAsync<WishlistItemStatus>(items.Select(x => x.Id).ToArray()))
                .ToDictionary(x => x.Id);

        return new WishlistResponse(
            [..items.Select(x => WishlistItemResponse.From(x, statuses.GetValueOrDefault(x.Id)))],
            [..packages.Select(PackageResponse.From)]);
    }
}
