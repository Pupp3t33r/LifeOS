using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Wishlist;

/// One wishlist package as the Wallet reads it (ADR-0022). Its rollup status ("2 of 4
/// bought") is derived client-side over the items sharing this [Id]; not stored here.
public sealed record PackageResponse(Guid Id, string Name, DateTimeOffset CreatedAt) {
    public static PackageResponse From(Package package) =>
        new(package.Id, package.Name, package.CreatedAt);
}
