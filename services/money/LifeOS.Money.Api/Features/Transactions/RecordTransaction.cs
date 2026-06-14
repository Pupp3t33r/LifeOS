using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;
using LifeOS.Money.Api.Projections;
using LifeOS.Money.Api.Validation;
using Marten;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace LifeOS.Money.Api.Features.Transactions;

public static class RecordTransaction
{
    public static RouteHandlerBuilder Register(IEndpointRouteBuilder endpoints)
    {
        return endpoints.MapPost("/accounts/{accountId:guid}/transactions", HandleAsync)
            .WithValidation<RecordTransactionRequest>()
            .WithName(nameof(RecordTransaction))
            .WithSummary("Record a transaction (income or expense) against an account. Idempotent on TransactionId (ADR-0003).");
    }

    private static async Task<IResult> HandleAsync(
        Guid accountId,
        RecordTransactionRequest request,
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

        if (account.RecordedTransactionIds.Contains(request.TransactionId))
        {
            var existing = await session.Query<TransactionRecord>()
                .FirstOrDefaultAsync(t => t.TransactionId == request.TransactionId, cancellationToken);

            if (existing is not null && PayloadMatches(existing, request))
            {
                var currentBalance = account.Balances.GetValueOrDefault(request.Currency);
                return Results.Ok(ToResponse(existing, currentBalance));
            }

            return Results.Problem(
                statusCode: StatusCodes.Status409Conflict,
                title: "Conflict",
                detail: $"Transaction '{request.TransactionId}' is already recorded on account '{accountId}' with different data.");
        }

        var previousBalance = account.Balances.GetValueOrDefault(request.Currency);
        var recordedAt = DateTimeOffset.UtcNow;
        var @event = account.RecordTransaction(
            request.TransactionId,
            request.Amount,
            request.Currency,
            request.Description,
            request.OccurredAt,
            recordedAt);

        session.Events.Append(accountId, @event);
        await session.SaveChangesAsync(cancellationToken);

        var newBalance = previousBalance + request.Amount;
        return Results.Created(
            $"/api/accounts/{accountId}/transactions/{request.TransactionId}",
            ToResponse(@event, newBalance));
    }

    private static bool PayloadMatches(TransactionRecord existing, RecordTransactionRequest request)
    {
        return existing.Amount == request.Amount
            && existing.Currency == request.Currency
            && existing.Description == request.Description
            && existing.OccurredAt == request.OccurredAt;
    }

    private static RecordTransactionResponse ToResponse(TransactionRecord existing, decimal balanceForCurrency) =>
        new(
            existing.AccountId,
            existing.TransactionId,
            existing.Amount,
            existing.Currency,
            existing.Description,
            existing.OccurredAt,
            existing.RecordedAt,
            balanceForCurrency);

    private static RecordTransactionResponse ToResponse(TransactionRecorded @event, decimal newBalance) =>
        new(
            @event.AccountId,
            @event.TransactionId,
            @event.Amount,
            @event.Currency,
            @event.Description,
            @event.OccurredAt,
            @event.RecordedAt,
            newBalance);
}
