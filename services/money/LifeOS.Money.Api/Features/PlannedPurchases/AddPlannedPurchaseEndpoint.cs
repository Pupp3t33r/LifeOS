using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.PlannedPurchases;

public static class AddPlannedPurchaseEndpoint
{
    // A planned purchase — "I intend to buy X this month" (ADR-0018) — lands on the
    // period in the URL as an event, not a separate aggregate. Always spending, so the
    // client sends positive magnitudes and the server signs them negative (ADR-0019).
    // Idempotent on EntryId (ADR-0003): a duplicate throws
    // DuplicatePlannedPurchaseException -> 409, which the Wallet outbox treats as
    // already-applied.
    [WolverinePost("/months/{year}/{month}/planned-purchases")]
    public static async Task<PlannedPurchaseWriteResponse> Handle(
        int year,
        int month,
        AddPlannedPurchaseRequest request,
        HttpContext context,
        IDocumentSession session)
    {
        var userId = context.GetUserId();
        var periodId = PeriodStream.IdFor(userId, year, month);

        var lines = request.Lines
            .Select(x => new Line(
                x.Description, new CurrencyAmount(-x.Amount, request.Currency), x.CategoryId, x.WishlistItemId,
                x.Quantity, x.UnitDimension))
            .ToList();
        var addedAt = DateTimeOffset.UtcNow;

        var stream = await session.Events.FetchForWriting<AccountingPeriod>(periodId);
        var period = stream.Aggregate ?? new AccountingPeriod();
        var added = period.AddPlannedPurchase(
            periodId, userId, year, month, request.EntryId, lines, addedAt, request.Description,
            deadline: request.Deadline);

        stream.AppendOne(added);
        await session.SaveChangesAsync();

        var total = new CurrencyAmount(lines.Sum(x => x.Amount.Amount), request.Currency);
        return new PlannedPurchaseWriteResponse(periodId, request.EntryId, lines, total, addedAt);
    }
}
