namespace LifeOS.Money.Api.Domain.Events;

using LifeOS.Money.Api.Domain;

/// An everyday income/expense actual on the accounting period (ADR-0016/0019). Not
/// balance-bearing and never touches a savings account — that is a
/// <c>SavingsMovementRecorded</c> (ADR-0026). The entry total is Σ line amounts
/// (signed). Idempotent on [EntryId] (ADR-0003).
///
/// <see cref="Recurring"/> is set only when this flow is the confirmation of a
/// recurring occurrence (ADR-0017): it back-references the occurrence so the
/// projection can mark it paid. Null for an ad-hoc flow.
public sealed record FlowRecorded(
    Guid PeriodId,
    string OwnerId,
    int Year,
    int Month,
    Guid EntryId,
    FlowDirection Direction,
    IReadOnlyList<Line> Lines,
    DateTimeOffset OccurredAt,
    DateTimeOffset RecordedAt,
    string? Description,
    RecurringReference? Recurring = null);
