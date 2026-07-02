namespace LifeOS.Money.Api.Domain.Events;

/// A recurring payment was cancelled (ADR-0017) — terminal; future occurrences stop
/// surfacing. <see cref="Refunded"/> records the cancellation's refund disposition
/// (ADR-0028 §6): for a payment plan the user chooses refund / no-refund; Live cancels
/// are <c>false</c>. The refund itself, when applicable, is a separate FlowRecorded(in)
/// on the active period — its mechanics are a later concern; this flag only records intent.
public sealed record RecurringPaymentCancelled(Guid RecurringId, bool Refunded, DateTimeOffset CancelledAt);
