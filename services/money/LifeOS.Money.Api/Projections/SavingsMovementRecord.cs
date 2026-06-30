using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;

namespace LifeOS.Money.Api.Projections;

public sealed class SavingsMovementRecord
{
    public Guid Id { get; set; }
    public Guid AccountId { get; set; }
    public Guid MovementId { get; set; }
    public CurrencyAmount Amount { get; set; } = new(0, string.Empty);
    public MovementSource Source { get; set; }
    public string? Description { get; set; }
    public DateTimeOffset OccurredAt { get; set; }
    public DateTimeOffset RecordedAt { get; set; }
}
