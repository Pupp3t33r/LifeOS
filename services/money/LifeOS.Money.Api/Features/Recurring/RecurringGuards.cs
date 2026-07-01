using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Recurring;
using LifeOS.Money.Api.Http;

namespace LifeOS.Money.Api.Features.Recurring;

/// HTTP-facing guards shared by the recurring mutation endpoints, so the domain
/// aggregate stays free of HTTP concerns (it throws plain exceptions as backstops).
internal static class RecurringGuards
{
    /// Owner scoping: a recurring payment owned by someone else is indistinguishable
    /// from one that does not exist (404, never a 403 that leaks existence).
    public static void RequireOwner(RecurringPayment recurring, HttpContext context)
    {
        if (recurring.OwnerId != context.GetUserId())
        {
            throw new NotFoundException($"Recurring payment '{recurring.Id}' was not found.");
        }
    }

    public static void RequireActive(RecurringPayment recurring)
    {
        if (recurring.Status != RecurringStatus.Active)
        {
            throw new ConflictException(
                $"Recurring payment '{recurring.Id}' is cancelled and cannot be modified.");
        }
    }

    public static void RequireMode(RecurringPayment recurring, ScheduleMode mode)
    {
        if (recurring.Mode != mode)
        {
            throw new ConflictException(
                $"This operation requires a {RecurringMapping.ModeString(mode)} schedule; " +
                $"recurring payment '{recurring.Id}' is {RecurringMapping.ModeString(recurring.Mode)}.");
        }
    }
}
