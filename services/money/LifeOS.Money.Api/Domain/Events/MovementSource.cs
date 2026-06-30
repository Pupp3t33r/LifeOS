namespace LifeOS.Money.Api.Domain.Events;

/// What produced a <see cref="SavingsMovementRecorded"/> (ADR-0026 §4): a deliberate
/// user deposit/withdrawal, or a close-flow allocation (surplus deposit / deficit
/// withdrawal, ADR-0021).
public enum MovementSource {
    Manual,
    Close,
}
