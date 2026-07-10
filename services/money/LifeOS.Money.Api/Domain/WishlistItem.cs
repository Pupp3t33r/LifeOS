namespace LifeOS.Money.Api.Domain;

/// A wishlist want (ADR-0022) — a non-event-sourced Marten document, one per item, that
/// is current-state CRUD (add / edit desire / repackage / remove). The item document is
/// never mutated when the want is planned/financed/bought — that commitment state is a
/// derived <see cref="Projections.WishlistItemStatus"/> projection (ADR-0034).
///
/// [Estimate] is optional (ADR-0030): a want may have no known price (a domain auto-add
/// with no MSRP); cost is pinned later from real money. [Recurrence] (ADR-0034) is the
/// once/reusable keystone the Board tray filters on; it is user-authored here.
public sealed class WishlistItem {
    /// Client-assigned (ADR-0003) — create is idempotent on the id.
    public Guid Id { get; set; }

    /// The owner's Keycloak subject (ADR-0004).
    public string OwnerId { get; set; } = string.Empty;

    /// The package this item belongs to (≤1), or null when ungrouped.
    public Guid? PackageId { get; set; }

    /// Domain-object link (e.g. board-games/{bggId}); descriptive metadata lives in the
    /// owning service, not here (ADR-0030).
    public ExternalReference? ExternalRef { get; set; }

    /// User-entered estimate (ADR-0008), or null when unknown (ADR-0030).
    public CurrencyAmount? Estimate { get; set; }

    public string? Name { get; set; }

    public string? Notes { get; set; }

    /// Once vs reusable (ADR-0034) — the Board tray keystone. Defaults to Once.
    public WishlistRecurrence Recurrence { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
}
