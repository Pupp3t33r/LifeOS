namespace LifeOS.Money.Api.Domain;

/// A managed category (ADR-0024) — the one budgeting category per spending line.
/// System categories are immutable code constants with fixed Guids (see
/// <see cref="SystemCategories"/>); user categories are per-owner Marten documents
/// with full CRUD. The categories overlay unions the two at read time.
public sealed class Category {
    /// Fixed Guid for system categories; client-assigned (ADR-0003) for user ones.
    public Guid Id { get; set; }

    /// Null for system categories; the owner's Keycloak subject for user ones.
    public string? OwnerId { get; set; }

    public string Name { get; set; } = string.Empty;

    /// Domain services this category maps to (system categories only) — a list, so
    /// a category isn't tied to a single store. Null for user categories.
    public IReadOnlyList<string>? ServiceTypes { get; set; }

    /// True for the immutable, code-defined system categories.
    public bool System { get; set; }

    /// Soft-archive (user categories only): retired from the picker, but historical
    /// lines and budgets still resolve by id.
    public bool Archived { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
}
