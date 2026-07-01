using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Http;
using Marten;
using Wolverine.Http;
using Domain = LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Recurring;

public static class SkipOccurrenceEndpoint
{
    // Skip an occurrence (ADR-0017): appends OccurrenceSkipped to the occurrence's
    // due-date period. A pure skip — arrears carry-make-up (ADR-0020) is deferred.
    // Idempotent: a second confirm/skip of the same occurrence is a 409.
    [WolverinePost("/recurring/{id}/occurrences/skip")]
    public static async Task<SkipOccurrenceResponse> Handle(
        Guid id,
        SkipOccurrenceRequest request,
        HttpContext context,
        IDocumentSession session)
    {
        var userId = context.GetUserId();

        if (string.IsNullOrWhiteSpace(request.OccurrenceRef))
        {
            throw new BadRequestException("OccurrenceRef is required.");
        }

        var recurring = await session.LoadAsync<RecurringPayment>(id);
        if (recurring is null || recurring.OwnerId != userId)
        {
            throw new NotFoundException($"Recurring payment '{id}' was not found.");
        }

        RecurringGuards.RequireActive(recurring);

        if (!RecurringOccurrences.TryResolve(recurring, request.OccurrenceRef, out var dueDate, out _))
        {
            throw new NotFoundException(
                $"Occurrence '{request.OccurrenceRef}' was not found on recurring payment '{id}'.");
        }

        var preferences = await session.LoadAsync<Domain.UserPreferences>(userId)
            ?? Domain.UserPreferences.Defaults(userId);
        var (year, month) = MonthPeriod.ContainingPeriod(dueDate, preferences.MonthStartDay);
        var periodId = PeriodStream.IdFor(userId, year, month);
        var backRef = new RecurringReference(id, request.OccurrenceRef);
        var recordedAt = DateTimeOffset.UtcNow;

        var stream = await session.Events.FetchForWriting<AccountingPeriod>(periodId);
        var period = stream.Aggregate ?? new AccountingPeriod();
        var skipped = period.SkipOccurrence(periodId, userId, year, month, backRef, recordedAt);
        stream.AppendOne(skipped);
        await session.SaveChangesAsync();

        return new SkipOccurrenceResponse(periodId, request.OccurrenceRef, year, month, recordedAt);
    }
}
