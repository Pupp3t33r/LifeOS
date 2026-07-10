using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Http;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Wishlist;

public static class CreatePackageEndpoint {
    [WolverinePost("/wishlist/packages")]
    public static async Task<IResult> Handle(
        CreatePackageRequest request,
        HttpContext context,
        IDocumentSession session) {
        var userId = context.GetUserId();

        var existing = await session.LoadAsync<Package>(request.Id);
        if (existing is not null) {
            if (existing.OwnerId != userId) {
                throw new NotFoundException($"Package '{request.Id}' was not found.");
            }
            return Results.Ok(PackageResponse.From(existing));
        }

        var package = new Package {
            Id = request.Id,
            OwnerId = userId,
            Name = request.Name.Trim(),
            CreatedAt = DateTimeOffset.UtcNow,
        };
        session.Store(package);
        await session.SaveChangesAsync();

        return Results.Created($"/api/wishlist/packages/{package.Id}", PackageResponse.From(package));
    }
}
