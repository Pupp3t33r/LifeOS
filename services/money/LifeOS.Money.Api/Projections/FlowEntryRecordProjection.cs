using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;
using Marten.Events.Projections;

namespace LifeOS.Money.Api.Projections;

public sealed partial class FlowEntryRecordProjection : EventProjection
{
    public FlowEntryRecord Create(FlowRecorded @event)
    {
        var currency = @event.Lines[0].Amount.Currency;
        var total = @event.Lines.Sum(x => x.Amount.Amount);
        return new FlowEntryRecord
        {
            Id = @event.EntryId,
            PeriodId = @event.PeriodId,
            OwnerId = @event.OwnerId,
            Year = @event.Year,
            Month = @event.Month,
            Direction = @event.Direction,
            Lines = @event.Lines,
            Total = new CurrencyAmount(total, currency),
            OccurredAt = @event.OccurredAt,
            RecordedAt = @event.RecordedAt,
            Description = @event.Description
        };
    }
}
