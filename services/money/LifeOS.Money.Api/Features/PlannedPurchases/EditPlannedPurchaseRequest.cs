namespace LifeOS.Money.Api.Features.PlannedPurchases;

/// Edits an unpaid planned purchase in place (ADR-0018): replaces its lines and
/// description. The entry id is the URL; [Currency] is the single entry currency.
/// [Deadline] (ADR-0034) is the optional "buy by" date; editing it may move the buy to a
/// different period (the client re-derives and re-files if so).
public sealed record EditPlannedPurchaseRequest(
    string Currency,
    string? Description,
    IReadOnlyList<PlannedPurchaseLine> Lines,
    DateOnly? Deadline = null);
