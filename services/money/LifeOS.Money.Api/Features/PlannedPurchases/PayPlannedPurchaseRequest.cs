namespace LifeOS.Money.Api.Features.PlannedPurchases;

/// Pays a planned purchase (ADR-0018): records a <c>FlowRecorded</c> in the planned
/// purchase's own period, back-referencing it so it reads as paid. [EntryId] is the
/// client-assigned id of the resulting flow (idempotency). [OccurredAt] is the actual
/// payment date. [Amount] optionally adjusts what was actually paid (a positive
/// magnitude, collapsing to a single line under the planned purchase's category, like
/// ADR-0029's amount-only adjustment); omit it to record the planned lines as-is.
public sealed record PayPlannedPurchaseRequest(
    Guid EntryId,
    DateTimeOffset OccurredAt,
    decimal? Amount,
    string? Description);
