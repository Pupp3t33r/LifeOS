using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Http;
using Marten;
using Wolverine.Http;
using Domain = LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.UserPreferences;

public static class SetMonthStartDayEndpoint
{
    [WolverinePut("/preferences/month-start-day")]
    public static async Task<PreferencesResponse> Handle(
        SetMonthStartDayRequest request,
        HttpContext context,
        IDocumentSession session,
        IClosedMonthGuard closedMonths)
    {
        var userId = context.GetUserId();

        // Re-anchoring is locked after the first close (ADR-0013): it would
        // re-bucket dates across locked, audited months.
        if (await closedMonths.HasClosedMonthAsync(userId, session))
        {
            throw new ConflictException(
                "Month start day cannot be changed after a month has been closed.");
        }

        var prefs = await session.LoadAsync<Domain.UserPreferences>(userId)
            ?? Domain.UserPreferences.Defaults(userId);

        prefs.MonthStartDay = request.MonthStartDay;
        session.Store(prefs);
        await session.SaveChangesAsync();

        return new PreferencesResponse(
            prefs.MonthStartDay,
            prefs.DisplayCurrency,
            prefs.DisplayCurrency is not null);
    }
}
