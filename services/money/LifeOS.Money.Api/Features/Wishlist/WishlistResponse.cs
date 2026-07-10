namespace LifeOS.Money.Api.Features.Wishlist;

/// The owner's whole wishlist (ADR-0022): items (each zipped with its derived status)
/// and packages. The Board tray filters idle + reusable items client-side; the List and
/// package rollups read both collections.
public sealed record WishlistResponse(
    IReadOnlyList<WishlistItemResponse> Items,
    IReadOnlyList<PackageResponse> Packages);
