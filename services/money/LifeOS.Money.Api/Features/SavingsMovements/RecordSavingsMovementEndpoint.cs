using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;
using LifeOS.Money.Api.Http;
using Wolverine.Http;
using Wolverine.Marten;

namespace LifeOS.Money.Api.Features.SavingsMovements;

public static class RecordSavingsMovementEndpoint
{
    // Account-scoped transactions are savings movements only (ADR-0016/0026):
    // deliberate deposits/withdrawals, never everyday spending. The route is
    // retained from the pre-ADR endpoint per ADR-0016; everyday income/expense is a
    // flow on the period (POST /months/{year}/{month}/transactions). This endpoint
    // records manual movements; close-flow allocations (Source = Close) are written
    // by the month-close handler, not here.
    [WolverinePost("/accounts/{accountId}/transactions")]
    public static (RecordSavingsMovementResponse, Events) Handle(
        Guid accountId,
        RecordSavingsMovementRequest request,
        HttpContext context,
        [WriteAggregate] Account account)
    {
        var userId = context.GetUserId();
        if (account.OwnerId != userId)
        {
            throw new NotFoundException($"Account '{accountId}' was not found.");
        }

        if (request.Currency != account.Currency)
        {
            throw new ConflictException(
                $"Movement currency '{request.Currency}' does not match account currency '{account.Currency}'.");
        }

        if (account.RecordedMovementIds.Contains(request.MovementId))
        {
            throw new ConflictException(
                $"Savings movement '{request.MovementId}' is already recorded on account '{accountId}'.");
        }

        var amount = new CurrencyAmount(request.Amount, request.Currency);
        var recordedAt = DateTimeOffset.UtcNow;
        var recorded = account.RecordSavingsMovement(
            request.MovementId,
            amount,
            request.OccurredAt,
            recordedAt,
            MovementSource.Manual,
            request.Description);

        var newBalance = new CurrencyAmount(account.Balance.Amount + request.Amount, account.Currency);

        var response = new RecordSavingsMovementResponse(
            accountId,
            request.MovementId,
            amount,
            MovementSource.Manual,
            request.Description,
            request.OccurredAt,
            recordedAt,
            newBalance);

        return (response, [recorded]);
    }
}
