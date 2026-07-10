namespace LifeOS.Money.Api.Domain.Events;

using LifeOS.Money.Api.Domain;

/// An unpaid planned purchase edited in place (ADR-0018): replaces the entry's [Lines]
/// and [Description] on the same [EntryId]. Only valid while the entry is live — not
/// once it has been paid (a confirming flow exists) or cancelled.
public sealed record PlannedPurchaseEdited(
    Guid PeriodId,
    string OwnerId,
    int Year,
    int Month,
    Guid EntryId,
    IReadOnlyList<Line> Lines,
    DateTimeOffset EditedAt,
    string? Description,
    DateOnly? Deadline = null);
