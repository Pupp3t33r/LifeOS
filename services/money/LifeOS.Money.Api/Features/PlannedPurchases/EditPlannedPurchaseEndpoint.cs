using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.PlannedPurchases;

public static class EditPlannedPurchaseEndpoint
{
    // Edit an unpaid planned purchase in place (ADR-0018). Editing an unknown entry is
    // 404 (PlannedPurchaseNotFoundException); editing a cancelled or already-paid one
    // is 409 (PlannedPurchaseConflictException) — both enforced by the aggregate.
    [WolverinePut("/months/{year}/{month}/planned-purchases/{entryId}")]
    public static async Task<PlannedPurchaseWriteResponse> Handle(
        int year,
        int month,
        Guid entryId,
        EditPlannedPurchaseRequest request,
        HttpContext context,
        IDocumentSession session)
    {
        var userId = context.GetUserId();
        var periodId = PeriodStream.IdFor(userId, year, month);

        var lines = request.Lines
            .Select(x => new Line(x.Description, new CurrencyAmount(-x.Amount, request.Currency), x.CategoryId))
            .ToList();
        var editedAt = DateTimeOffset.UtcNow;

        var stream = await session.Events.FetchForWriting<AccountingPeriod>(periodId);
        var period = stream.Aggregate ?? new AccountingPeriod();
        var edited = period.EditPlannedPurchase(
            periodId, userId, year, month, entryId, lines, editedAt, request.Description);

        stream.AppendOne(edited);
        await session.SaveChangesAsync();

        var total = new CurrencyAmount(lines.Sum(x => x.Amount.Amount), request.Currency);
        return new PlannedPurchaseWriteResponse(periodId, entryId, lines, total, editedAt);
    }
}
