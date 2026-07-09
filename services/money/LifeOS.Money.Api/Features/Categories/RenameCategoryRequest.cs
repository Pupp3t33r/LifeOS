namespace LifeOS.Money.Api.Features.Categories;

/// Rename a user category (ADR-0033). The id is in the route; the body carries the
/// new [Name] only.
public sealed record RenameCategoryRequest(string Name);
