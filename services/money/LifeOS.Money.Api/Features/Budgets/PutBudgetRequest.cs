using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Budgets;

/// Upserts a period's whole budget (ADR-0035) — the single-editor Budget view saves the
/// entire record at once (savings target + limits + tracked set), not per-category calls.
/// [SavingsTarget] null clears the target; [Limits] replaces the limit map; only ids in
/// [TrackedCategories] are scored (untracked spend pools into the client-side Other bucket).
public sealed record PutBudgetRequest(
    CurrencyAmount? SavingsTarget,
    IReadOnlyList<CategoryLimit> Limits,
    IReadOnlyList<Guid> TrackedCategories);
