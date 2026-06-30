using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Flows;

public static class RecordFlowEndpoint
{
    // Everyday income/expense actuals land on the accounting period (ADR-0016), not
    // on an account. The period is picked by the URL (the client derives year/month
    // from the actual date and the user's month-start-day, ADR-0013) and scoped to
    // the caller. Idempotent on EntryId (ADR-0003): a duplicate throws
    // DuplicateFlowException -> 409, which the Wallet outbox treats as already-applied.
    [WolverinePost("/months/{year}/{month}/transactions")]
    public static async Task<RecordFlowResponse> Handle(
        int year,
        int month,
        RecordFlowRequest request,
        HttpContext context,
        IDocumentSession session)
    {
        var userId = context.GetUserId();
        var periodId = PeriodStream.IdFor(userId, year, month);

        var direction = request.Direction == "in" ? FlowDirection.In : FlowDirection.Out;
        var sign = direction == FlowDirection.Out ? -1m : 1m;
        var lines = request.Lines
            .Select(x => new Line(x.Description, new CurrencyAmount(sign * x.Amount, request.Currency), x.CategoryId))
            .ToList();

        var recordedAt = DateTimeOffset.UtcNow;

        var stream = await session.Events.FetchForWriting<AccountingPeriod>(periodId);
        var period = stream.Aggregate ?? new AccountingPeriod();
        var recorded = period.RecordFlow(
            periodId,
            userId,
            year,
            month,
            request.EntryId,
            direction,
            lines,
            request.OccurredAt,
            recordedAt,
            request.Description);

        stream.AppendOne(recorded);
        await session.SaveChangesAsync();

        var total = new CurrencyAmount(lines.Sum(x => x.Amount.Amount), request.Currency);
        return new RecordFlowResponse(
            periodId, request.EntryId, request.Direction, lines, request.OccurredAt, recordedAt, total);
    }
}
