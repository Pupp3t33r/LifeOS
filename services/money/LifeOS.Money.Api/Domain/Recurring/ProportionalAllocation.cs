using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Domain.Recurring;

/// Splits a Materialized plan's root <c>Items</c> across its scheduled payments
/// (ADR-0028 §4). A payment of amount P against items totalling T records the items
/// scaled by P/T. To keep every payment's lines summing exactly to P *and* the
/// cumulative per-item total over the whole plan equal to the items exactly, the split
/// is computed on the running **cumulative**: the amount allocated to an item after the
/// k-th payment is <c>round(item × Σ(1..k) / T)</c>, and payment k's slice is
/// <c>cumulative(k) − cumulative(k−1)</c>. Because each cumulative row sums to the
/// cumulative paid, the per-payment slice sums to P automatically; and since the last
/// cumulative equals T (the balance invariant), every item is allocated exactly by the
/// end — regardless of the order payments are confirmed in.
///
/// Rounding is largest-remainder to the minor unit (2 decimals). A plan has a single
/// direction, so all item amounts share one sign and the split runs on magnitudes.
internal static class ProportionalAllocation
{
    private const int MinorUnitDecimals = 2;
    private const decimal MinorUnit = 0.01m;

    /// The slice of <paramref name="items"/> financed by the payment at 0-based
    /// <paramref name="paymentIndex"/> in <paramref name="scheduleAmounts"/> (which must
    /// be in the order payments are made — chronological). Returned lines carry each
    /// item's description/category with the sliced amount; zero-amount slices are dropped.
    /// Assumes Σ <paramref name="scheduleAmounts"/> == Σ <paramref name="items"/> (the
    /// balance invariant) and a non-empty item list.
    public static IReadOnlyList<Line> Slice(
        IReadOnlyList<Line> items,
        IReadOnlyList<decimal> scheduleAmounts,
        int paymentIndex)
    {
        var sign = items[0].Amount.Amount < 0 ? -1m : 1m;
        var absItems = items.Select(x => Math.Abs(x.Amount.Amount)).ToList();
        var total = absItems.Sum();

        var cumulativeBefore = 0m;
        for (var i = 0; i < paymentIndex; i++) {
            cumulativeBefore += Math.Abs(scheduleAmounts[i]);
        }
        var cumulativeAfter = cumulativeBefore + Math.Abs(scheduleAmounts[paymentIndex]);

        var allocatedBefore = AllocateCumulative(absItems, total, cumulativeBefore);
        var allocatedAfter = AllocateCumulative(absItems, total, cumulativeAfter);

        var currency = items[0].Amount.Currency;
        var lines = new List<Line>();
        for (var j = 0; j < items.Count; j++) {
            var magnitude = allocatedAfter[j] - allocatedBefore[j];
            if (magnitude == 0m) {
                continue;
            }

            lines.Add(items[j] with { Amount = new CurrencyAmount(sign * magnitude, currency) });
        }

        return lines;
    }

    // Largest-remainder allocation of `cumulative` across the item magnitudes, each
    // floored to the minor unit, with the leftover minor units handed to the largest
    // fractional remainders so the result sums exactly to the rounded cumulative.
    private static List<decimal> AllocateCumulative(
        IReadOnlyList<decimal> absItems, decimal total, decimal cumulative)
    {
        var target = Math.Round(cumulative, MinorUnitDecimals, MidpointRounding.AwayFromZero);
        var floors = new decimal[absItems.Count];
        var remainders = new (decimal Remainder, int Index)[absItems.Count];
        var allocated = 0m;
        for (var j = 0; j < absItems.Count; j++) {
            var exact = total == 0m ? 0m : absItems[j] * cumulative / total;
            var floor = Math.Floor(exact / MinorUnit) * MinorUnit;
            floors[j] = floor;
            remainders[j] = (exact - floor, j);
            allocated += floor;
        }

        var leftover = (int)Math.Round((target - allocated) / MinorUnit, MidpointRounding.AwayFromZero);
        foreach (var (_, index) in remainders
                     .OrderByDescending(x => x.Remainder)
                     .ThenBy(x => x.Index)
                     .Take(Math.Max(0, leftover))) {
            floors[index] += MinorUnit;
        }

        return [.. floors];
    }
}
