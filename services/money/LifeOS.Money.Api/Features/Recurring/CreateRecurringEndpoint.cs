using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;
using LifeOS.Money.Api.Http;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Recurring;

public static class CreateRecurringEndpoint
{
    // Create a recurring payment/income (ADR-0017; contents-at-root per ADR-0028).
    // Idempotent on the client-assigned RecurringId (ADR-0003): a repeat id is a 409,
    // which the client treats as already-applied. Live requires a rule + estimate;
    // Materialized requires balanced Items + schedule payments, authored once here (a
    // plan is immutable except cancel).
    [WolverinePost("/recurring")]
    public static async Task<RecurringResponse> Handle(
        CreateRecurringRequest request,
        HttpContext context,
        IDocumentSession session)
    {
        var userId = context.GetUserId();

        var existing = await session.Events.FetchStreamStateAsync(request.RecurringId);
        if (existing is not null)
        {
            throw new ConflictException($"Recurring payment '{request.RecurringId}' already exists.");
        }

        var direction = RecurringMapping.ParseDirection(request.Direction);
        var createdAt = DateTimeOffset.UtcNow;

        RecurringPaymentCreated created;
        if (request.Mode == "materialized")
        {
            var items = RecurringMapping.ToLines(request.Items ?? [], direction, request.Currency);
            var scheduleLines = (request.ScheduleLines ?? [])
                .Select(x => RecurringMapping.ToScheduleLine(x, direction, request.Currency))
                .ToList();
            created = RecurringPayment.CreateMaterialized(
                request.RecurringId, userId, request.Name, direction, request.Currency,
                request.CategoryId, request.AccountId, items, scheduleLines, createdAt);
        }
        else
        {
            var rule = request.Rule
                ?? throw new BadRequestException("A live recurring payment requires a rule.");
            RecurringRuleValidation.Validate(rule);
            var estimate = RecurringMapping.ToLines(request.EstimateLines ?? [], direction, request.Currency);
            created = RecurringPayment.CreateLive(
                request.RecurringId, userId, request.Name, direction, request.Currency,
                request.CategoryId, request.AccountId, rule, estimate, createdAt);
        }

        session.Events.StartStream<RecurringPayment>(request.RecurringId, created);
        await session.SaveChangesAsync();

        var aggregate = new RecurringPayment();
        aggregate.Apply(created);
        return RecurringMapping.ToResponse(aggregate);
    }
}
