namespace LifeOS.Money.Api.Features.PlannedPurchases;

/// Adds a planned purchase to the period in the URL (ADR-0018). [EntryId] is
/// client-assigned for idempotency (ADR-0003). [Currency] is the single entry currency
/// (ADR-0019); a planned purchase is always spending, so the server signs the lines
/// negative. There is no date — a planned purchase belongs to its period, not a day.
public sealed record AddPlannedPurchaseRequest(
    Guid EntryId,
    string Currency,
    string? Description,
    IReadOnlyList<PlannedPurchaseLine> Lines);
