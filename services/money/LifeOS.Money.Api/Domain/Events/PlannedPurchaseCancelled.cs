namespace LifeOS.Money.Api.Domain.Events;

/// A planned purchase cancelled (ADR-0018): terminal for that [EntryId] within the
/// period — it drops out of the canvas and the worklist. Deferring an unpaid entry to
/// the next period at close (also a cancel here + add there) is the close flow's job
/// (ADR-0021), not modelled yet.
public sealed record PlannedPurchaseCancelled(
    Guid PeriodId,
    string OwnerId,
    int Year,
    int Month,
    Guid EntryId,
    DateTimeOffset CancelledAt);
