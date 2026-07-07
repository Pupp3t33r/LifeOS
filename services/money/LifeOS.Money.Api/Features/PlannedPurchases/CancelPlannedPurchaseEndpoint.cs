using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.PlannedPurchases;

public static class CancelPlannedPurchaseEndpoint
{
    // Cancel a planned purchase (ADR-0018) — terminal; it drops out of the canvas and
    // the worklist. Cancelling an unknown entry is 404; cancelling an already-cancelled
    // or paid one is 409 — enforced by the aggregate.
    [WolverineDelete("/months/{year}/{month}/planned-purchases/{entryId}")]
    public static async Task<CancelPlannedPurchaseResponse> Handle(
        int year,
        int month,
        Guid entryId,
        HttpContext context,
        IDocumentSession session)
    {
        var userId = context.GetUserId();
        var periodId = PeriodStream.IdFor(userId, year, month);

        var stream = await session.Events.FetchForWriting<AccountingPeriod>(periodId);
        var period = stream.Aggregate ?? new AccountingPeriod();
        var cancelled = period.CancelPlannedPurchase(
            periodId, userId, year, month, entryId, DateTimeOffset.UtcNow);

        stream.AppendOne(cancelled);
        await session.SaveChangesAsync();

        return new CancelPlannedPurchaseResponse(periodId, entryId);
    }
}
