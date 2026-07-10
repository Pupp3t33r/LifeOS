using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Budgets;

/// One period's budget as the Plan Budget view edits it (ADR-0035): the savings target,
/// the per-category limits, and the tracked-category subset. A period with no budget yet
/// reads as an empty default (null target, no limits, none tracked).
public sealed record PeriodBudgetResponse(
    int Year,
    int Month,
    CurrencyAmount? SavingsTarget,
    IReadOnlyList<CategoryLimit> Limits,
    IReadOnlyList<Guid> TrackedCategories) {
    public static PeriodBudgetResponse From(PeriodBudget budget) =>
        new(budget.Year,
            budget.Month,
            budget.SavingsTarget,
            [..budget.CategoryLimits.Select(x => new CategoryLimit(x.Key, x.Value))],
            budget.TrackedCategories);

    public static PeriodBudgetResponse Empty(int year, int month) =>
        new(year, month, null, [], []);
}
