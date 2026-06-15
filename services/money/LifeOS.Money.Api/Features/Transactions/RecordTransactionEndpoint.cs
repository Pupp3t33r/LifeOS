using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;
using LifeOS.Money.Api.Http;
using Wolverine.Http;
using Wolverine.Marten;

namespace LifeOS.Money.Api.Features.Transactions;

public static class RecordTransactionEndpoint
{
    [WolverinePost("/accounts/{accountId}/transactions")]
    public static RecordTransactionResponse Handle(
        Guid accountId,
        RecordTransactionRequest request,
        HttpContext context,
        [WriteAggregate] Domain.Account account,
        ref TransactionRecorded created)
    {
        var userId = context.GetUserId();
        if (account.OwnerId != userId)
        {
            throw new NotFoundException($"Account '{accountId}' was not found.");
        }

        if (request.Currency != account.Currency)
        {
            throw new ConflictException(
                $"Transaction currency '{request.Currency}' does not match account currency '{account.Currency}'.");
        }

        if (account.RecordedTransactionIds.Contains(request.TransactionId))
        {
            throw new ConflictException(
                $"Transaction '{request.TransactionId}' is already recorded on account '{accountId}'.");
        }

        var amount = new CurrencyAmount(request.Amount, request.Currency);
        var recordedAt = DateTimeOffset.UtcNow;
        created = account.RecordTransaction(
            request.TransactionId,
            amount,
            request.Description,
            request.OccurredAt,
            recordedAt);

        var newBalance = new CurrencyAmount(account.Balance.Amount + request.Amount, account.Currency);

        return new RecordTransactionResponse(
            accountId,
            request.TransactionId,
            amount,
            request.Description,
            request.OccurredAt,
            recordedAt,
            newBalance);
    }
}
