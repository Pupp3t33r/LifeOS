namespace LifeOS.Money.Api.Features.Categories;

/// One category as the Wallet picker needs it (ADR-0024): an entry in the overlay
/// of system built-ins and the owner's user categories. <see cref="System"/> marks
/// the immutable built-ins the client can't edit; <see cref="ServiceTypes"/> is the
/// domain-link hint (system categories only), null for user categories.
public sealed record CategoryResponse(
    Guid Id,
    string Name,
    bool System,
    IReadOnlyList<string>? ServiceTypes);
