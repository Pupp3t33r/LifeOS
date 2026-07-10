using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Projections;

/// The derived commitment status of one wishlist want (ADR-0022 as re-vocabularied by
/// ADR-0034). [Id] equals the <see cref="WishlistItem.Id"/> it tracks (1:1). Maintained
/// by <see cref="WishlistItemStatusProjection"/> by folding <c>AccountingPeriod</c> and
/// <c>RecurringPayment</c> events; never hand-edited. A want with no status document has
/// never been committed and reads as <see cref="WishlistCommitment.Idle"/>.
///
/// [Status] is a pure function of the working sets below (Bought &gt; Financed &gt;
/// Planned &gt; Idle); the sets are what the fold mutates, the status is recomputed each
/// time. Context fields ([PlannedYear]/[PlannedMonth], [PlanId], [BoughtDate]) are
/// populated only for their corresponding status.
public sealed class WishlistItemStatus {
    /// The wishlist item's id (Marten identity).
    public Guid Id { get; set; }

    public string OwnerId { get; set; } = string.Empty;

    public WishlistCommitment Status { get; set; }

    public int? PlannedYear { get; set; }
    public int? PlannedMonth { get; set; }

    /// The financing payment plan (RecurringPayment) — set when Financed.
    public Guid? PlanId { get; set; }

    /// The date the single purchase was paid — set when Bought.
    public DateOnly? BoughtDate { get; set; }

    // --- fold working sets (denormalized so cancel/edit can recompute without rescans) ---

    /// Live planned-purchase EntryIds referencing this item (→ Planned).
    public List<Guid> ActivePlannedEntryIds { get; set; } = [];

    /// Active financing plan RecurringIds referencing this item (→ Financed).
    public List<Guid> FinancingPlanIds { get; set; } = [];

    /// Planned entries whose paying flow has landed (→ Bought).
    public List<Guid> BoughtViaPlannedEntryIds { get; set; } = [];

    /// A flow line referenced this item directly (a buy not routed through a planned
    /// purchase) (→ Bought).
    public bool BoughtDirect { get; set; }
}
