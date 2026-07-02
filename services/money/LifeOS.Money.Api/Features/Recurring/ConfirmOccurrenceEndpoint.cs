using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Recurring;
using LifeOS.Money.Api.Http;
using Marten;
using Wolverine.Http;
using Domain = LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Recurring;

public static class ConfirmOccurrenceEndpoint
{
    // Confirm an occurrence as paid (ADR-0017): appends a FlowRecorded to the period
    // its actual date maps to (ADR-0016), carrying the { recurringId, occurrenceRef }
    // back-ref so the occurrence reads as paid. Recurring never auto-posts — this is
    // user-driven. Idempotent on EntryId (409) and on the occurrence itself: a second
    // confirm/skip of the same occurrence in its period is a 409.
    [WolverinePost("/recurring/{id}/occurrences/confirm")]
    public static async Task<ConfirmOccurrenceResponse> Handle(
        Guid id,
        ConfirmOccurrenceRequest request,
        HttpContext context,
        IDocumentSession session)
    {
        var userId = context.GetUserId();

        var recurring = await session.LoadAsync<RecurringPayment>(id);
        if (recurring is null || recurring.OwnerId != userId)
        {
            throw new NotFoundException($"Recurring payment '{id}' was not found.");
        }

        RecurringGuards.RequireActive(recurring);

        if (!RecurringOccurrences.TryResolve(recurring, request.OccurrenceRef, out _, out var expectedLines))
        {
            throw new NotFoundException(
                $"Occurrence '{request.OccurrenceRef}' was not found on recurring payment '{id}'.");
        }

        // A payment plan (Materialized) records its scheduled proportional slice exactly —
        // no override (ADR-0028 §4). Override remains a Live affordance (variable actuals).
        if (recurring.Mode == ScheduleMode.Materialized && request.Lines is { Count: > 0 })
        {
            throw new BadRequestException(
                "A payment-plan payment records its scheduled slice; overriding the amount/lines is not supported (ADR-0028).");
        }

        var lines = request.Lines is { Count: > 0 }
            ? RecurringMapping.ToLines(request.Lines, recurring.Direction, recurring.Currency)
            : expectedLines.ToList();
        if (lines.Count == 0)
        {
            throw new BadRequestException("The occurrence has no line items to confirm; provide lines.");
        }

        var preferences = await session.LoadAsync<Domain.UserPreferences>(userId)
            ?? Domain.UserPreferences.Defaults(userId);
        var occurredDate = DateOnly.FromDateTime(request.OccurredAt.UtcDateTime);
        var (year, month) = MonthPeriod.ContainingPeriod(occurredDate, preferences.MonthStartDay);
        var periodId = PeriodStream.IdFor(userId, year, month);
        var backRef = new RecurringReference(id, request.OccurrenceRef);
        var recordedAt = DateTimeOffset.UtcNow;

        var stream = await session.Events.FetchForWriting<AccountingPeriod>(periodId);
        var period = stream.Aggregate ?? new AccountingPeriod();
        var recorded = period.RecordFlow(
            periodId, userId, year, month, request.EntryId, recurring.Direction, lines,
            request.OccurredAt, recordedAt, request.Description, backRef);
        stream.AppendOne(recorded);
        await session.SaveChangesAsync();

        var total = new CurrencyAmount(lines.Sum(x => x.Amount.Amount), recurring.Currency);
        return new ConfirmOccurrenceResponse(
            periodId, request.EntryId, request.OccurrenceRef, total, request.OccurredAt, recordedAt);
    }
}
