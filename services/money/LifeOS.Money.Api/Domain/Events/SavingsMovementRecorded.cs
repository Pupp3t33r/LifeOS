namespace LifeOS.Money.Api.Domain.Events;

/// A deliberate change to a savings-account balance (ADR-0026 §4) — deposits,
/// withdrawals, inter-account transfers, and the close-day surplus/deficit. This
/// replaces the old generic `TransactionRecorded` on Account streams: everyday
/// income/expense never lands here — that is a `FlowRecorded` on the period
/// (ADR-0016). [Amount] is signed and in the account's currency (+ deposit,
/// − withdrawal). [TransferId] is reserved for the deferred transfers feature
/// (ADR-0009); [FxRate] is present only on close allocations (display→account at
/// `ClosingFxRates`), absent on manual single-currency moves.
public sealed record SavingsMovementRecorded(
    Guid AccountId,
    Guid MovementId,
    CurrencyAmount Amount,
    MovementSource Source,
    DateTimeOffset OccurredAt,
    DateTimeOffset RecordedAt,
    string? Description,
    Guid? TransferId,
    decimal? FxRate);
