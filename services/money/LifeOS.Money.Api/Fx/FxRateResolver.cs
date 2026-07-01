using LifeOS.Money.Api.Domain.Fx;

namespace LifeOS.Money.Api.Fx;

/// Pure resolution of "the applicable rate" from a set of stored <see cref="FxRate"/>
/// rows, honoring ADR-0015 precedence and forward-fill. Kept side-effect free so the
/// forward-fill / precedence rules are unit-testable without a database.
///
/// Precedence is <b>per pair, priority-first</b> (ADR-0015: "prefer the Belarusbank
/// rate when published; fall back to Frankfurter otherwise… the fallback exists only
/// for pairs Belarusbank does not cover"): the highest-priority source that has any
/// row for the pair wins, and within that source the freshest row on/before the
/// requested date is taken (forward-fill across weekends/holidays/gaps). A source not
/// present in the priority list is treated as disabled and never returned — the hook
/// the future per-user source Settings (priority + on/off) plugs into.
public static class FxRateResolver
{
    /// Resolve a single rate for the pair the candidates describe, as of
    /// <paramref name="asOf"/>. Candidates should already be the rows for one
    /// <c>(Base, Quote)</c> pair. Returns null when no enabled source has a row
    /// dated on or before <paramref name="asOf"/>.
    public static FxRate? Resolve(
        IEnumerable<FxRate> candidates,
        DateOnly asOf,
        IReadOnlyList<string> sourcePriority)
    {
        var eligible = candidates.Where(x => x.Date <= asOf).ToList();
        if (eligible.Count == 0)
        {
            return null;
        }

        foreach (var source in sourcePriority)
        {
            var best = eligible
                .Where(x => string.Equals(x.Source, source, StringComparison.OrdinalIgnoreCase))
                .OrderByDescending(x => x.Date)
                .FirstOrDefault();
            if (best is not null)
            {
                return best;
            }
        }

        return null;
    }
}
