namespace LifeOS.Money.Api.Features.SavingsMovements;

/// A manual deposit (positive [Amount]) or withdrawal (negative) on a savings
/// account (ADR-0026 §4). Everyday income/expense does not come here — that is a
/// flow on the period (ADR-0016). [MovementId] is client-assigned for idempotency
/// (ADR-0003).
public sealed record RecordSavingsMovementRequest(
    Guid MovementId,
    decimal Amount,
    string Currency,
    string? Description,
    DateTimeOffset OccurredAt);
