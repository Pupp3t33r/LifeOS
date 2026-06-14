using System.Security.Claims;

namespace LifeOS.Money.Api.Auth;

public static class AuthExtensions
{
    public static string GetUserId(this HttpContext context)
    {
        return context.User.FindFirstValue("sub")
            ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? context.User.FindFirstValue("preferred_username")
            ?? throw new UnauthorizedAccessException("Authenticated token has no subject claim.");
    }
}
