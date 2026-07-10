using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;
using Marten;
using Marten.Events.Projections;

namespace LifeOS.Money.Api.Projections;

/// Derives each wishlist want's commitment status (ADR-0034; supersedes ADR-0022's
/// status enum). Folds two event families:
///
/// - <c>AccountingPeriod</c> — <c>PlannedPurchaseAdded/Edited/Cancelled</c> drive
///   Planned; a paying <c>FlowRecorded</c> (a line referencing the item, or one whose
///   <c>PlannedEntryId</c> settles a planned entry that referenced it) drives Bought.
/// - <c>RecurringPayment</c> — a <c>RecurringPaymentCreated</c> whose <c>PlanItem</c>
///   references the item drives Financed; <c>RecurringPaymentCancelled</c> reverses it.
///
/// Runs inline (consistent with this service's other read-models; the async option
/// ADR-0022 allowed is a deferred projection-strategy call). Cancel/edit events do not
/// carry the item refs, so those handlers query the working sets for affected docs — a
/// bounded, low-volume lookup at solo scale.
public sealed partial class WishlistItemStatusProjection : EventProjection {
    public async Task Project(PlannedPurchaseAdded e, IDocumentOperations ops) {
        foreach (var itemId in ItemIds(e.Lines)) {
            var doc = await LoadOrCreate(ops, itemId, e.OwnerId);
            if (!doc.ActivePlannedEntryIds.Contains(e.EntryId)) {
                doc.ActivePlannedEntryIds.Add(e.EntryId);
            }
            doc.PlannedYear = e.Year;
            doc.PlannedMonth = e.Month;
            Recompute(doc);
            ops.Store(doc);
        }
    }

    public async Task Project(PlannedPurchaseEdited e, IDocumentOperations ops) {
        var referenced = ItemIds(e.Lines).ToHashSet();

        // Drop the entry from items the edit no longer references.
        var previously = await ops.Query<WishlistItemStatus>()
            .Where(x => x.ActivePlannedEntryIds.Contains(e.EntryId))
            .ToListAsync();
        foreach (var doc in previously.Where(x => !referenced.Contains(x.Id))) {
            doc.ActivePlannedEntryIds.Remove(e.EntryId);
            Recompute(doc);
            ops.Store(doc);
        }

        // Add it to items the edit now references.
        foreach (var itemId in referenced) {
            var doc = await LoadOrCreate(ops, itemId, e.OwnerId);
            if (!doc.ActivePlannedEntryIds.Contains(e.EntryId)) {
                doc.ActivePlannedEntryIds.Add(e.EntryId);
            }
            doc.PlannedYear = e.Year;
            doc.PlannedMonth = e.Month;
            Recompute(doc);
            ops.Store(doc);
        }
    }

    public async Task Project(PlannedPurchaseCancelled e, IDocumentOperations ops) {
        var docs = await ops.Query<WishlistItemStatus>()
            .Where(x => x.ActivePlannedEntryIds.Contains(e.EntryId))
            .ToListAsync();
        foreach (var doc in docs) {
            doc.ActivePlannedEntryIds.Remove(e.EntryId);
            Recompute(doc);
            ops.Store(doc);
        }
    }

    public async Task Project(FlowRecorded e, IDocumentOperations ops) {
        var boughtOn = DateOnly.FromDateTime(e.OccurredAt.UtcDateTime);

        // A flow line referencing an item directly buys it.
        foreach (var itemId in ItemIds(e.Lines)) {
            var doc = await LoadOrCreate(ops, itemId, e.OwnerId);
            doc.BoughtDirect = true;
            doc.BoughtDate = boughtOn;
            Recompute(doc);
            ops.Store(doc);
        }

        // Paying a planned purchase buys every item that planned entry referenced (the
        // paying flow may have been amount-adjusted and dropped the line ref, so this
        // joins on the entry, not the line).
        if (e.PlannedEntryId is Guid entryId) {
            var docs = await ops.Query<WishlistItemStatus>()
                .Where(x => x.ActivePlannedEntryIds.Contains(entryId))
                .ToListAsync();
            foreach (var doc in docs) {
                doc.ActivePlannedEntryIds.Remove(entryId);
                if (!doc.BoughtViaPlannedEntryIds.Contains(entryId)) {
                    doc.BoughtViaPlannedEntryIds.Add(entryId);
                }
                doc.BoughtDate = boughtOn;
                Recompute(doc);
                ops.Store(doc);
            }
        }
    }

    public async Task Project(RecurringPaymentCreated e, IDocumentOperations ops) {
        var itemIds = e.Items
            .Where(x => x.WishlistItemId is not null)
            .Select(x => x.WishlistItemId!.Value)
            .Distinct();
        foreach (var itemId in itemIds) {
            var doc = await LoadOrCreate(ops, itemId, e.OwnerId);
            if (!doc.FinancingPlanIds.Contains(e.RecurringId)) {
                doc.FinancingPlanIds.Add(e.RecurringId);
            }
            doc.PlanId = e.RecurringId;
            Recompute(doc);
            ops.Store(doc);
        }
    }

    public async Task Project(RecurringPaymentCancelled e, IDocumentOperations ops) {
        var docs = await ops.Query<WishlistItemStatus>()
            .Where(x => x.FinancingPlanIds.Contains(e.RecurringId))
            .ToListAsync();
        foreach (var doc in docs) {
            doc.FinancingPlanIds.Remove(e.RecurringId);
            Recompute(doc);
            ops.Store(doc);
        }
    }

    private static IEnumerable<Guid> ItemIds(IReadOnlyList<Line> lines) =>
        lines.Where(x => x.WishlistItemId is not null)
            .Select(x => x.WishlistItemId!.Value)
            .Distinct();

    private static async Task<WishlistItemStatus> LoadOrCreate(
        IDocumentOperations ops, Guid itemId, string ownerId) =>
        await ops.LoadAsync<WishlistItemStatus>(itemId)
        ?? new WishlistItemStatus { Id = itemId, OwnerId = ownerId };

    /// Status is Bought &gt; Financed &gt; Planned &gt; Idle over the working sets; context
    /// fields are cleared when their status does not hold.
    private static void Recompute(WishlistItemStatus d) {
        d.Status = (d.BoughtDirect || d.BoughtViaPlannedEntryIds.Count > 0) ? WishlistCommitment.Bought
            : d.FinancingPlanIds.Count > 0 ? WishlistCommitment.Financed
            : d.ActivePlannedEntryIds.Count > 0 ? WishlistCommitment.Planned
            : WishlistCommitment.Idle;

        if (d.Status != WishlistCommitment.Planned) {
            d.PlannedYear = null;
            d.PlannedMonth = null;
        }
        if (d.Status != WishlistCommitment.Financed) {
            d.PlanId = null;
        }
        if (d.Status != WishlistCommitment.Bought) {
            d.BoughtDate = null;
        }
    }
}
