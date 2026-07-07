using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;
using LifeOS.Money.Api.Http;
using LifeOS.Money.Api.Projections;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.PlannedPurchases;

public static class PayPlannedPurchaseEndpoint
{
    // Pay a planned purchase (ADR-0018): a FlowRecorded on the planned purchase's own
    // period, back-referencing it so it reads as paid — the same "projected -> actual"
    // move as confirming a recurring occurrence. The flow's lines default to the
    // planned breakdown; an optional Amount adjusts what was actually paid (collapsed to
    // one line under the planned purchase's category, like ADR-0029's amount-only
    // adjustment). Idempotent on the new EntryId (409) and on the planned purchase
    // itself: a second pay is a 409 (already paid), enforced by the aggregate.
    [WolverinePost("/months/{year}/{month}/planned-purchases/{plannedEntryId}/pay")]
    public static async Task<PayPlannedPurchaseResponse> Handle(
        int year,
        int month,
        Guid plannedEntryId,
        PayPlannedPurchaseRequest request,
        HttpContext context,
        IDocumentSession session)
    {
        var userId = context.GetUserId();
        var periodId = PeriodStream.IdFor(userId, year, month);

        var record = await session.Query<PlannedPurchaseRecord>()
            .FirstOrDefaultAsync(x => x.Id == plannedEntryId && x.OwnerId == userId);
        if (record is null)
        {
            throw new NotFoundException(
                $"Planned purchase '{plannedEntryId}' was not found in this period.");
        }

        var currency = record.Total.Currency;
        List<Line> lines;
        if (request.Amount is decimal amount)
        {
            // Amount-only adjustment: one line at what was paid, under the planned
            // purchase's category (its single line's, or none if it was itemised).
            var categoryId = record.Lines.Count == 1 ? record.Lines[0].CategoryId : null;
            lines = [new Line(null, new CurrencyAmount(-amount, currency), categoryId)];
        }
        else
        {
            lines = record.Lines.ToList();
        }

        var recordedAt = DateTimeOffset.UtcNow;

        var stream = await session.Events.FetchForWriting<AccountingPeriod>(periodId);
        var period = stream.Aggregate ?? new AccountingPeriod();
        var recorded = period.RecordFlow(
            periodId, userId, year, month, request.EntryId, FlowDirection.Out, lines,
            request.OccurredAt, recordedAt, request.Description ?? record.Description,
            recurring: null, plannedEntryId: plannedEntryId);

        stream.AppendOne(recorded);
        await session.SaveChangesAsync();

        var total = new CurrencyAmount(lines.Sum(x => x.Amount.Amount), currency);
        return new PayPlannedPurchaseResponse(
            periodId, request.EntryId, plannedEntryId, total, request.OccurredAt, recordedAt);
    }
}
