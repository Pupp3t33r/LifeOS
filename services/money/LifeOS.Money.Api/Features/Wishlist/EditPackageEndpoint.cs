using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Http;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Wishlist;

public static class EditPackageEndpoint {
    [WolverinePut("/wishlist/packages/{id}")]
    public static async Task<PackageResponse> Handle(
        Guid id,
        EditPackageRequest request,
        HttpContext context,
        IDocumentSession session) {
        var userId = context.GetUserId();

        var package = await session.LoadAsync<Package>(id);
        if (package is null || package.OwnerId != userId) {
            throw new NotFoundException($"Package '{id}' was not found.");
        }

        package.Name = request.Name.Trim();
        session.Store(package);
        await session.SaveChangesAsync();

        return PackageResponse.From(package);
    }
}
