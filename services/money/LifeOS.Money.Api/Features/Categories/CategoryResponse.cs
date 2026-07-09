using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Categories;

/// One category as the Wallet needs it (ADR-0024): an entry in the overlay of
/// system built-ins and the owner's user categories. <see cref="System"/> marks
/// the immutable built-ins the client can't edit; <see cref="ServiceTypes"/> is the
/// domain-link hint (system categories only), null for user categories.
/// <see cref="Archived"/> (ADR-0033) lets one client provider serve both the
/// picker (filters active) and the management screen (Wallet ADR-0008); it is
/// always false for system categories.
public sealed record CategoryResponse(
    Guid Id,
    string Name,
    bool System,
    IReadOnlyList<string>? ServiceTypes,
    bool Archived) {
    public static CategoryResponse From(Category category) =>
        new(category.Id, category.Name, category.System, category.ServiceTypes, category.Archived);
}
