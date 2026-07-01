namespace LifeOS.Money.Api.Features.Recurring;

/// One line of a recurring estimate or schedule line. <see cref="Amount"/> is a
/// positive magnitude; the recurring payment's direction sets the sign (mirrors the
/// flow-recording contract).
public sealed record RecurringLineRequest(decimal Amount, Guid? CategoryId, string? Description);
