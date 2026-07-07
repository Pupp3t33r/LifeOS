using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;
using Marten;
using Marten.Events.Projections;

namespace LifeOS.Money.Api.Projections;

public sealed partial class PlannedPurchaseRecordProjection : EventProjection
{
    public PlannedPurchaseRecord Create(PlannedPurchaseAdded @event)
    {
        var currency = @event.Lines[0].Amount.Currency;
        var total = @event.Lines.Sum(x => x.Amount.Amount);
        return new PlannedPurchaseRecord
        {
            Id = @event.EntryId,
            PeriodId = @event.PeriodId,
            OwnerId = @event.OwnerId,
            Year = @event.Year,
            Month = @event.Month,
            Lines = @event.Lines,
            Total = new CurrencyAmount(total, currency),
            AddedAt = @event.AddedAt,
            Description = @event.Description,
            Origin = @event.Origin
        };
    }

    public async Task Project(PlannedPurchaseEdited @event, IDocumentOperations ops)
    {
        var record = await ops.LoadAsync<PlannedPurchaseRecord>(@event.EntryId);
        if (record is null)
        {
            return;
        }

        var currency = @event.Lines[0].Amount.Currency;
        record.Lines = @event.Lines;
        record.Total = new CurrencyAmount(@event.Lines.Sum(x => x.Amount.Amount), currency);
        record.Description = @event.Description;
        ops.Store(record);
    }

    // Cancel is terminal: the planned purchase drops out of every read, so the row is
    // removed (its guards still live on the AccountingPeriod aggregate, the source of
    // truth, so replay stays correct).
    public void Project(PlannedPurchaseCancelled @event, IDocumentOperations ops) =>
        ops.Delete<PlannedPurchaseRecord>(@event.EntryId);
}
