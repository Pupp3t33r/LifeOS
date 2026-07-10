using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Budgets;

public static class GetBudgetEndpoint {
    // The period's budget as the Plan Budget view loads it to edit (ADR-0035). Owner-scoped;
    // a period with no budget yet returns an empty default rather than 404, so the view
    // opens on blank sliders.
    [WolverineGet("/budgets")]
    public static async Task<PeriodBudgetResponse> Handle(
        int year,
        int month,
        HttpContext context,
        IQuerySession session) {
        var userId = context.GetUserId();
        var id = PeriodBudget.IdFor(userId, year, month);

        var budget = await session.LoadAsync<PeriodBudget>(id);
        return budget is null
            ? PeriodBudgetResponse.Empty(year, month)
            : PeriodBudgetResponse.From(budget);
    }
}
