namespace LifeOS.Money.Api.Domain.Events;

/// A recurring payment was cancelled (ADR-0017) — terminal; future occurrences stop
/// surfacing. Any optional reimbursement is recorded separately as a fresh
/// FlowRecorded(in) on the active period, not represented here.
public sealed record RecurringPaymentCancelled(Guid RecurringId, DateTimeOffset CancelledAt);
