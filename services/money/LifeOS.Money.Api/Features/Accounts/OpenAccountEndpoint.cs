using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Http;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Accounts;

public static class OpenAccountEndpoint
{
    [WolverinePost("/accounts")]
    public static async Task<(CreationResponse, AccountResponse)> Handle(
        OpenAccountRequest request,
        HttpContext context,
        IDocumentSession session)
    {
        var userId = context.GetUserId();

        var existing = await session.LoadAsync<Account>(request.AccountId);
        if (existing is not null)
        {
            if (existing.OwnerId != userId)
            {
                throw new NotFoundException($"Account '{request.AccountId}' was not found.");
            }

            if (existing.Name != request.Name || existing.Currency != request.Currency)
            {
                throw new ConflictException(
                    $"Account '{request.AccountId}' already exists with different data.");
            }

            return (
                new CreationResponse($"/api/accounts/{request.AccountId}"),
                ToResponse(existing));
        }

        var openingBalance = request.OpeningBalanceAmount.HasValue
            ? new CurrencyAmount(request.OpeningBalanceAmount.Value, request.Currency)
            : new CurrencyAmount(0, request.Currency);

        var opened = Account.Open(
            request.AccountId,
            userId,
            request.Name,
            request.Currency,
            openingBalance);

        session.Events.StartStream<Account>(request.AccountId, opened);
        await session.SaveChangesAsync();

        var created = await session.LoadAsync<Account>(request.AccountId);
        return (
            new CreationResponse($"/api/accounts/{request.AccountId}"),
            ToResponse(created!));
    }

    private static AccountResponse ToResponse(Account account) =>
        new(account.Id, account.OwnerId, account.Name, account.Balance, account.Currency, account.OpenedAt);
}
