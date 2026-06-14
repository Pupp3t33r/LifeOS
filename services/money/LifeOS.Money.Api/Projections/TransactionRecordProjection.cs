using LifeOS.Money.Api.Domain.Events;
using Marten.Events.Projections;

namespace LifeOS.Money.Api.Projections;

public sealed partial class TransactionRecordProjection : EventProjection
{
    public TransactionRecord Create(TransactionRecorded @event)
    {
        return new TransactionRecord
        {
            Id = @event.TransactionId,
            AccountId = @event.AccountId,
            TransactionId = @event.TransactionId,
            Amount = @event.Amount,
            Currency = @event.Currency,
            Description = @event.Description,
            OccurredAt = @event.OccurredAt,
            RecordedAt = @event.RecordedAt
        };
    }
}
