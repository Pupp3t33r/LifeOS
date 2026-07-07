namespace LifeOS.Money.Api.Features.PlannedPurchases;

/// Edits an unpaid planned purchase in place (ADR-0018): replaces its lines and
/// description. The entry id is the URL; [Currency] is the single entry currency.
public sealed record EditPlannedPurchaseRequest(
    string Currency,
    string? Description,
    IReadOnlyList<PlannedPurchaseLine> Lines);
