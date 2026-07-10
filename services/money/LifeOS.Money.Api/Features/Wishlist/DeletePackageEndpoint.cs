using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Wishlist;

public static class DeletePackageEndpoint {
    [WolverineDelete("/wishlist/packages/{id}")]
    public static async Task<IResult> Handle(
        Guid id,
        HttpContext context,
        IDocumentSession session) {
        var userId = context.GetUserId();

        var package = await session.LoadAsync<Package>(id);
        if (package is null || package.OwnerId != userId) {
            return Results.NoContent();
        }

        // Ungroup any items pointing at this package, then remove it (a package carries no
        // financial state, so nothing else references it).
        var items = await session.Query<WishlistItem>()
            .Where(x => x.OwnerId == userId && x.PackageId == id)
            .ToListAsync();
        foreach (var item in items) {
            item.PackageId = null;
            session.Store(item);
        }
        session.Delete(package);
        await session.SaveChangesAsync();
        return Results.NoContent();
    }
}
