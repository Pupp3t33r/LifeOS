namespace LifeOS.Money.Api.Features.Recurring;

/// Edit a recurring payment's header (ADR-0017): name, category, and account context.
public sealed record EditRecurringRequest(string Name, Guid? CategoryId, Guid? AccountId);
