using LifeOS.Money.Api.Auth;
using Marten;
using Wolverine.Http;
using Domain = LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.UserPreferences;

public static class SetDisplayCurrencyEndpoint
{
    [WolverinePut("/preferences/display-currency")]
    public static async Task<PreferencesResponse> Handle(
        SetDisplayCurrencyRequest request,
        HttpContext context,
        IDocumentSession session)
    {
        var userId = context.GetUserId();
        var prefs = await session.LoadAsync<Domain.UserPreferences>(userId)
            ?? Domain.UserPreferences.Defaults(userId);

        prefs.DisplayCurrency = request.Currency;
        session.Store(prefs);
        await session.SaveChangesAsync();

        return new PreferencesResponse(
            prefs.MonthStartDay,
            prefs.DisplayCurrency,
            prefs.UnitSystem,
            prefs.DisplayCurrency is not null);
    }
}
