using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Http;
using LifeOS.Money.Api.Projections;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Wishlist;

public static class EditWishlistItemEndpoint {
    [WolverinePut("/wishlist/items/{id}")]
    public static async Task<WishlistItemResponse> Handle(
        Guid id,
        EditWishlistItemRequest request,
        HttpContext context,
        IDocumentSession session) {
        var userId = context.GetUserId();

        var item = await session.LoadAsync<WishlistItem>(id);
        if (item is null || item.OwnerId != userId) {
            throw new NotFoundException($"Wishlist item '{id}' was not found.");
        }

        item.Recurrence = WishlistMapping.ParseRecurrence(request.Recurrence);
        item.Name = request.Name;
        item.Notes = request.Notes;
        item.Estimate = request.Estimate;
        item.PackageId = request.PackageId;
        item.ExternalRef = request.ExternalRef;
        session.Store(item);
        await session.SaveChangesAsync();

        var status = await session.LoadAsync<WishlistItemStatus>(id);
        return WishlistItemResponse.From(item, status);
    }
}
