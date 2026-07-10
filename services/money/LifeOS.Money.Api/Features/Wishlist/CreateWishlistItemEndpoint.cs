using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Http;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Wishlist;

public static class CreateWishlistItemEndpoint {
    [WolverinePost("/wishlist/items")]
    public static async Task<IResult> Handle(
        CreateWishlistItemRequest request,
        HttpContext context,
        IDocumentSession session) {
        var userId = context.GetUserId();

        // Idempotent on the client-assigned id (ADR-0003): a re-send returns the existing
        // row; a same-id/different-owner send is a not-found (never leak another owner).
        var existing = await session.LoadAsync<WishlistItem>(request.Id);
        if (existing is not null) {
            if (existing.OwnerId != userId) {
                throw new NotFoundException($"Wishlist item '{request.Id}' was not found.");
            }
            return Results.Ok(WishlistItemResponse.From(existing, status: null));
        }

        var item = new WishlistItem {
            Id = request.Id,
            OwnerId = userId,
            Recurrence = WishlistMapping.ParseRecurrence(request.Recurrence),
            Name = request.Name,
            Notes = request.Notes,
            Estimate = request.Estimate,
            PackageId = request.PackageId,
            ExternalRef = request.ExternalRef,
            CreatedAt = DateTimeOffset.UtcNow,
        };
        session.Store(item);
        await session.SaveChangesAsync();

        return Results.Created(
            $"/api/wishlist/items/{item.Id}", WishlistItemResponse.From(item, status: null));
    }
}
