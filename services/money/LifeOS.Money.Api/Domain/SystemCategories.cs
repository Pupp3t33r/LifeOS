namespace LifeOS.Money.Api.Domain;

/// The hardcoded, domain-linked system categories (ADR-0024). Defined in code with
/// fixed Guids and never stored per-user; the categories overlay unions these with
/// the owner's user categories. Books / Board Games / Video Games map to LifeOS
/// domain services (`ServiceTypes`) for Phase-2 auto-categorize — "Video Games" is
/// the category, not "Steam", so it can span stores later.
public static class SystemCategories {
    public static readonly Category Books = new() {
        Id = Guid.Parse("c1a7b000-0000-4000-8000-000000000001"),
        Name = "Books",
        ServiceTypes = ["books"],
        System = true,
    };

    public static readonly Category BoardGames = new() {
        Id = Guid.Parse("c1a7b000-0000-4000-8000-000000000002"),
        Name = "Board Games",
        ServiceTypes = ["board-games"],
        System = true,
    };

    public static readonly Category VideoGames = new() {
        Id = Guid.Parse("c1a7b000-0000-4000-8000-000000000003"),
        Name = "Video Games",
        ServiceTypes = ["steam"],
        System = true,
    };

    /// All system categories, in display order.
    public static readonly IReadOnlyList<Category> All = [Books, BoardGames, VideoGames];
}
