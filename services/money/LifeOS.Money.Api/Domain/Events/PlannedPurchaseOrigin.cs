namespace LifeOS.Money.Api.Domain.Events;

/// An optional soft reference on a planned purchase (ADR-0018): set only when the
/// entry was produced by the recurring carry-make-up operation (ADR-0020) — it names
/// the recurring and the occurrence date the make-up was carried from. Unused
/// otherwise; a forward-compatible field so the event contract need not change when
/// carry-make-up lands.
public sealed record PlannedPurchaseOrigin(Guid RecurringId, DateOnly CarriedFromDate);
