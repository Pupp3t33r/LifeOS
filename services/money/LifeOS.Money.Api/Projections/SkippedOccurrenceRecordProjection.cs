using LifeOS.Money.Api.Domain.Events;
using Marten.Events.Projections;

namespace LifeOS.Money.Api.Projections;

public sealed partial class SkippedOccurrenceRecordProjection : EventProjection
{
    public SkippedOccurrenceRecord Create(OccurrenceSkipped @event)
    {
        return new SkippedOccurrenceRecord
        {
            Id = @event.Occurrence.ToKey(),
            OwnerId = @event.OwnerId,
            RecurringId = @event.Occurrence.RecurringId,
            OccurrenceRef = @event.Occurrence.OccurrenceRef,
            Year = @event.Year,
            Month = @event.Month,
            RecordedAt = @event.RecordedAt
        };
    }
}
