namespace LifeOS.Money.Api.Domain;

/// A lightweight desire-side grouping of wishlist items (ADR-0022) — e.g. an all-in
/// board-game pledge grouping base + addons as separate <see cref="WishlistItem"/>s that
/// share this package's id. Carries no financial state; a package's status ("2 of 4
/// ordered") is a read-time rollup over its items' derived statuses, never stored.
public sealed class Package {
    /// Client-assigned (ADR-0003) — create is idempotent on the id.
    public Guid Id { get; set; }

    /// The owner's Keycloak subject (ADR-0004).
    public string OwnerId { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public DateTimeOffset CreatedAt { get; set; }
}
