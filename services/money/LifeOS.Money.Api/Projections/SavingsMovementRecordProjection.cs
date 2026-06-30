using LifeOS.Money.Api.Domain.Events;
using Marten.Events.Projections;

namespace LifeOS.Money.Api.Projections;

public sealed partial class SavingsMovementRecordProjection : EventProjection
{
    public SavingsMovementRecord Create(SavingsMovementRecorded @event)
    {
        return new SavingsMovementRecord
        {
            Id = @event.MovementId,
            AccountId = @event.AccountId,
            MovementId = @event.MovementId,
            Amount = @event.Amount,
            Source = @event.Source,
            Description = @event.Description,
            OccurredAt = @event.OccurredAt,
            RecordedAt = @event.RecordedAt
        };
    }
}
