using Marten;

namespace LifeOS.Money.Api.Features.UserPreferences;

/// Guards re-anchoring of <c>MonthStartDay</c>: changing the anchor re-buckets
/// historical dates across period boundaries, so ADR-0013 forbids it once the
/// owner has any <c>Closed</c> MonthlyReview (ADR-0007). In effect the start day
/// is a setup-time decision.
public interface IClosedMonthGuard
{
    Task<bool> HasClosedMonthAsync(string ownerId, IQuerySession session, CancellationToken cancellationToken = default);
}

/// MonthlyReview (PLAN §3.7) is not built yet, so no month can be closed — the
/// guard reports "none." This is the seam: when §3.7 lands, replace this with an
/// implementation that queries the MonthlyReview projection for a <c>Closed</c>
/// review owned by <paramref name="ownerId"/>. The endpoint contract (409 after a
/// close) is already correct; only this body changes.
public sealed class NoClosedMonthsGuard : IClosedMonthGuard
{
    public Task<bool> HasClosedMonthAsync(string ownerId, IQuerySession session, CancellationToken cancellationToken = default) =>
        Task.FromResult(false);
}
