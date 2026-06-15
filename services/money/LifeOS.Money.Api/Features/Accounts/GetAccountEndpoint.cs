using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Http;
using Wolverine.Http;
using Wolverine.Marten;

namespace LifeOS.Money.Api.Features.Accounts;

public static class GetAccountEndpoint
{
    [WolverineGet("/accounts/{accountId}")]
    public static AccountResponse Handle(
        Guid accountId,
        HttpContext context,
        [ReadAggregate] Account account)
    {
        var userId = context.GetUserId();
        if (account.OwnerId != userId)
        {
            throw new NotFoundException($"Account '{accountId}' was not found.");
        }

        return new AccountResponse(
            account.Id,
            account.OwnerId,
            account.Name,
            account.Balance,
            account.Currency,
            account.OpenedAt);
    }
}
