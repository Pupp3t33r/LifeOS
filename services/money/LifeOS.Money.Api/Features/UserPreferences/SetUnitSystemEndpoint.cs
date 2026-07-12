using LifeOS.Money.Api.Auth;
using Marten;
using Wolverine.Http;
using Domain = LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.UserPreferences;

public static class SetUnitSystemEndpoint
{
    // The unit-symbol selector (ADR-0036) — display-only. Switching it relabels every
    // quantity's symbol (kg↔lb, L↔gal, m↔ft) without touching any stored magnitude: Money
    // stores the dimension only and performs no conversions. Not locked by a closed month
    // (unlike MonthStartDay) because it re-buckets nothing.
    [WolverinePut("/preferences/unit-system")]
    public static async Task<PreferencesResponse> Handle(
        SetUnitSystemRequest request,
        HttpContext context,
        IDocumentSession session)
    {
        var userId = context.GetUserId();
        var prefs = await session.LoadAsync<Domain.UserPreferences>(userId)
            ?? Domain.UserPreferences.Defaults(userId);

        prefs.UnitSystem = request.UnitSystem;
        session.Store(prefs);
        await session.SaveChangesAsync();

        return new PreferencesResponse(
            prefs.MonthStartDay,
            prefs.DisplayCurrency,
            prefs.UnitSystem,
            prefs.DisplayCurrency is not null);
    }
}
