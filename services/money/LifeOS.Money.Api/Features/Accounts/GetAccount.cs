using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using Marten;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace LifeOS.Money.Api.Features.Accounts;

public static class GetAccount
{
    public static RouteHandlerBuilder Register(IEndpointRouteBuilder endpoints)
    {
        return endpoints.MapGet("/accounts/{accountId:guid}", HandleAsync)
            .WithName(nameof(GetAccount))
            .WithSummary("Get an account with its current per-currency balances.");
    }

    private static async Task<IResult> HandleAsync(
        Guid accountId,
        HttpContext httpContext,
        IDocumentSession session,
        CancellationToken cancellationToken)
    {
        var userId = httpContext.GetUserId();

        var account = await session.LoadAsync<Account>(accountId, cancellationToken);
        if (account is null || account.OwnerId != userId)
        {
            return Results.NotFound();
        }

        return Results.Ok(new AccountResponse(
            account.Id,
            account.OwnerId,
            account.Name,
            account.Balances,
            account.OpenedAt));
    }
}
