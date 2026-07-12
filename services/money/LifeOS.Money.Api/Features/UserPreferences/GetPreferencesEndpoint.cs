using LifeOS.Money.Api.Auth;
using Marten;
using Wolverine.Http;
using Domain = LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.UserPreferences;

public static class GetPreferencesEndpoint
{
    [WolverineGet("/preferences")]
    public static async Task<PreferencesResponse> Handle(
        HttpContext context,
        IQuerySession session)
    {
        var userId = context.GetUserId();
        var prefs = await session.LoadAsync<Domain.UserPreferences>(userId)
            ?? Domain.UserPreferences.Defaults(userId);

        return new PreferencesResponse(
            prefs.MonthStartDay,
            prefs.DisplayCurrency,
            prefs.UnitSystem,
            prefs.DisplayCurrency is not null);
    }
}
