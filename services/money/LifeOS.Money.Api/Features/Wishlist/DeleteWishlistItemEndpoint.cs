using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Http;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Wishlist;

public static class DeleteWishlistItemEndpoint {
    [WolverineDelete("/wishlist/items/{id}")]
    public static async Task<IResult> Handle(
        Guid id,
        HttpContext context,
        IDocumentSession session) {
        var userId = context.GetUserId();

        var item = await session.LoadAsync<WishlistItem>(id);
        if (item is null || item.OwnerId != userId) {
            // Idempotent delete: a gone/never-existed item is a no-op success.
            return Results.NoContent();
        }

        session.Delete(item);
        await session.SaveChangesAsync();
        return Results.NoContent();
    }
}
