using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Budgets;

public static class PutBudgetEndpoint {
    // Upsert the period's whole budget (ADR-0035). Idempotent on the deterministic
    // (owner, period) id — a re-send replaces the record. This is the single write the
    // Budget view makes; there is no per-category fan-out.
    [WolverinePut("/budgets")]
    public static async Task<PeriodBudgetResponse> Handle(
        int year,
        int month,
        PutBudgetRequest request,
        HttpContext context,
        IDocumentSession session) {
        var userId = context.GetUserId();
        var id = PeriodBudget.IdFor(userId, year, month);

        var budget = await session.LoadAsync<PeriodBudget>(id) ?? new PeriodBudget {
            Id = id,
            OwnerId = userId,
            Year = year,
            Month = month,
        };

        budget.SavingsTarget = request.SavingsTarget;
        budget.CategoryLimits = request.Limits.ToDictionary(x => x.CategoryId, x => x.Amount);
        budget.TrackedCategories = [..request.TrackedCategories.Distinct()];
        budget.UpdatedAt = DateTimeOffset.UtcNow;

        session.Store(budget);
        await session.SaveChangesAsync();

        return PeriodBudgetResponse.From(budget);
    }
}
