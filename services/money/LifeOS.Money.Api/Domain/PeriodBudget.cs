namespace LifeOS.Money.Api.Domain;

/// One owner's budget for one period (ADR-0035; supersedes ADR-0025's per-category-doc
/// storage). A single document holding the savings target, the per-category spending
/// limits, and the opt-in tracked-category subset — the whole unit the Plan Budget view
/// edits at once. Non-event-sourced user-authored state (the ADR-0013/0022/0025
/// precedent); actuals stay event-sourced and are grouped by <see cref="Projections.BudgetActuals"/>.
///
/// [Id] is deterministic from (owner, year, month) so upserts are idempotent.
/// [SavingsTarget] is null when unset. [CategoryLimits] maps a CategoryId → its limit
/// (display currency). [TrackedCategories] is the scored subset (ADR-0005 §5); a category
/// with a limit but off this list is not scored — its spend pools into the client-side
/// "Other" residual. All amounts are in the display currency (ADR-0008/0013).
public sealed class PeriodBudget {
    public Guid Id { get; set; }

    public string OwnerId { get; set; } = string.Empty;

    public int Year { get; set; }
    public int Month { get; set; }

    public CurrencyAmount? SavingsTarget { get; set; }

    public Dictionary<Guid, CurrencyAmount> CategoryLimits { get; set; } = [];

    public List<Guid> TrackedCategories { get; set; } = [];

    public DateTimeOffset UpdatedAt { get; set; }

    private static readonly Guid NamespaceId = Guid.Parse("b2d4c6e8-1a3b-5c7d-9e0f-2a4b6c8d0e1f");

    public static Guid IdFor(string ownerId, int year, int month) =>
        DeterministicGuid.Create(NamespaceId, $"{ownerId}/{year}/{month}");
}
