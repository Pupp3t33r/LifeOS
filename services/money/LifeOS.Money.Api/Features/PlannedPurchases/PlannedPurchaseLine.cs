namespace LifeOS.Money.Api.Features.PlannedPurchases;

/// One line of a planned purchase as the client sends it: a positive [Amount]
/// magnitude (a planned purchase is always spending, so the server signs it negative),
/// an optional budgeting [CategoryId] (ADR-0024), and an optional [Description].
public sealed record PlannedPurchaseLine(
    decimal Amount,
    Guid? CategoryId,
    string? Description);
