namespace LifeOS.Money.Api.Features.PlannedPurchases;

/// Acknowledges a cancelled planned purchase (ADR-0018): the period and the entry that
/// is now terminal and gone from every read.
public sealed record CancelPlannedPurchaseResponse(Guid PeriodId, Guid EntryId);
