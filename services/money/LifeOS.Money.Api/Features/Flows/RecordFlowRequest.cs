namespace LifeOS.Money.Api.Features.Flows;

/// Records an everyday income/expense actual on the active period (ADR-0016). The
/// period is taken from the URL (the client derives year/month from the actual date
/// and the user's month-start-day, ADR-0013). [Direction] is "in" or "out" and sets
/// the sign for every line; [Currency] is the single entry currency (ADR-0019).
/// [EntryId] is client-assigned for idempotency (ADR-0003).
public sealed record RecordFlowRequest(
    Guid EntryId,
    string Direction,
    string Currency,
    DateTimeOffset OccurredAt,
    string? Description,
    IReadOnlyList<RecordFlowLine> Lines);
