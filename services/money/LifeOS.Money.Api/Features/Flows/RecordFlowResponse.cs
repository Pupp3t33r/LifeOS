using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Flows;

public sealed record RecordFlowResponse(
    Guid PeriodId,
    Guid EntryId,
    string Direction,
    IReadOnlyList<Line> Lines,
    DateTimeOffset OccurredAt,
    DateTimeOffset RecordedAt,
    CurrencyAmount Total);
