using System.Globalization;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Recurring;

namespace LifeOS.Money.Api.Features.Recurring;

/// Resolves an occurrence reference (from get-occurrences) back to its due date and
/// default line breakdown on the owning recurring payment — shared by confirm and
/// skip. For Live the ref is the due date (<c>yyyy-MM-dd</c>) and the breakdown is the
/// estimate; for Materialized the ref is a schedule LineId, the due date comes from that
/// payment, and the breakdown is a **single reference line** at the scheduled amount
/// under the plan's category (ADR-0029 — no per-item slice; contents live on the plan).
internal static class RecurringOccurrences
{
    public static bool TryResolve(
        RecurringPayment recurring,
        string occurrenceRef,
        out DateOnly dueDate,
        out IReadOnlyList<Line> lines)
    {
        if (recurring.Mode == ScheduleMode.Live)
        {
            if (DateOnly.TryParseExact(occurrenceRef, "yyyy-MM-dd", CultureInfo.InvariantCulture,
                    DateTimeStyles.None, out dueDate))
            {
                lines = recurring.EstimateLines;
                return true;
            }

            lines = [];
            return false;
        }

        var line = recurring.ScheduleLines.FirstOrDefault(x => x.LineId.ToString() == occurrenceRef);
        if (line is not null)
        {
            dueDate = line.DueDate;
            lines = [recurring.ReferenceLineForOccurrence(line.LineId)];
            return true;
        }

        dueDate = default;
        lines = [];
        return false;
    }
}
