using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Validation;
using Marten;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace LifeOS.Money.Api.Features.Accounts;

public sealed record OpenAccountRequest(Guid AccountId, string Name);

public sealed record AccountResponse(
    Guid AccountId,
    string OwnerId,
    string Name,
    IReadOnlyDictionary<string, decimal> Balances,
    DateTimeOffset OpenedAt);

public static class OpenAccount
{
    public static RouteHandlerBuilder Register(IEndpointRouteBuilder endpoints)
    {
        return endpoints.MapPost("/accounts", HandleAsync)
            .WithValidation<OpenAccountRequest>()
            .WithName(nameof(OpenAccount))
            .WithSummary("Open a new account. Idempotent on AccountId (ADR-0003).");
    }

    private static async Task<IResult> HandleAsync(
        OpenAccountRequest request,
        HttpContext httpContext,
        IDocumentSession session,
        CancellationToken cancellationToken)
    {
        var userId = httpContext.GetUserId();

        var existing = await session.LoadAsync<Account>(request.AccountId, cancellationToken);
        if (existing is not null)
        {
            if (existing.OwnerId != userId)
            {
                return Results.NotFound();
            }

            if (existing.Name == request.Name)
            {
                return Results.Ok(ToResponse(existing));
            }

            return Results.Problem(
                statusCode: StatusCodes.Status409Conflict,
                title: "Conflict",
                detail: $"Account '{request.AccountId}' already exists with different data.");
        }

        var opened = Account.Open(request.AccountId, userId, request.Name, DateTimeOffset.UtcNow);
        session.Events.StartStream<Account>(request.AccountId, opened);
        await session.SaveChangesAsync(cancellationToken);

        var created = await session.LoadAsync<Account>(request.AccountId, cancellationToken);
        return Results.Created($"/api/accounts/{request.AccountId}", ToResponse(created!));
    }

    private static AccountResponse ToResponse(Account account) =>
        new(account.Id, account.OwnerId, account.Name, account.Balances, account.OpenedAt);
}
