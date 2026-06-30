using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Periods;

/// One recorded flow entry as the cockpit reads it. [Direction] is the wire string
/// "in"/"out" (matching the record endpoint); line [Amount]s are already signed
/// (ADR-0026), and [Total] is their Σ.
public sealed record FlowEntryResponse(
    Guid EntryId,
    string Direction,
    IReadOnlyList<Line> Lines,
    CurrencyAmount Total,
    DateTimeOffset OccurredAt,
    DateTimeOffset RecordedAt,
    string? Description);
