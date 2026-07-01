using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Recurring;
using LifeOS.Money.Api.Http;
using Wolverine.Http;
using Wolverine.Marten;

namespace LifeOS.Money.Api.Features.Recurring;

public static class AddScheduleLineEndpoint
{
    // Append a line to a Materialized schedule (ADR-0017). LineId is client-assigned
    // and becomes the occurrence's stable reference.
    [WolverinePost("/recurring/{id}/schedule-lines")]
    public static (RecurringResponse, Events) Handle(
        Guid id,
        ScheduleLineRequest request,
        HttpContext context,
        [WriteAggregate] RecurringPayment recurring)
    {
        RecurringGuards.RequireOwner(recurring, context);
        RecurringGuards.RequireActive(recurring);
        RecurringGuards.RequireMode(recurring, ScheduleMode.Materialized);
        ValidateLines(request);

        if (recurring.HasScheduleLine(request.LineId))
        {
            throw new ConflictException($"Schedule line '{request.LineId}' already exists.");
        }

        var line = RecurringMapping.ToScheduleLine(request, recurring.Direction, recurring.Currency);
        var added = recurring.AddScheduleLine(line);
        var view = recurring.Clone();
        view.Apply(added);
        return (RecurringMapping.ToResponse(view), [added]);
    }

    internal static void ValidateLines(ScheduleLineRequest request)
    {
        if (request.LineId == Guid.Empty)
        {
            throw new BadRequestException("LineId must be a non-empty UUID.");
        }

        if (request.Lines is null || request.Lines.Count == 0)
        {
            throw new BadRequestException("A schedule line needs at least one line-item.");
        }

        if (request.Lines.Any(x => x.Amount <= 0))
        {
            throw new BadRequestException("Each line amount must be a positive magnitude; direction sets the sign.");
        }
    }
}
