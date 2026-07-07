namespace LifeOS.Money.Api.Domain.Events;

using LifeOS.Money.Api.Domain;

/// A planned purchase added to an accounting period (ADR-0018): a line-itemed
/// intention to buy in this month that the canvas reads as reduced projected savings,
/// and that a confirming <c>FlowRecorded</c> (carrying this [EntryId] as its
/// <c>PlannedEntryId</c> back-ref) later turns into a real actual. Lives on the period
/// stream next to the flow actuals it becomes — no separate PurchaseOrder aggregate.
///
/// [Lines] carry the breakdown with signed amounts (ADR-0019/0026); a planned purchase
/// is always spending, so amounts are negative. Idempotent on [EntryId] (ADR-0003).
/// [Origin] is populated only by recurring carry-make-up (ADR-0020) and otherwise null.
public sealed record PlannedPurchaseAdded(
    Guid PeriodId,
    string OwnerId,
    int Year,
    int Month,
    Guid EntryId,
    IReadOnlyList<Line> Lines,
    DateTimeOffset AddedAt,
    string? Description,
    PlannedPurchaseOrigin? Origin = null);
