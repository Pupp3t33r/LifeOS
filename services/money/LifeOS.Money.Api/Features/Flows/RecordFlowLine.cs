namespace LifeOS.Money.Api.Features.Flows;

/// One line as the client sends it: a positive [Amount] magnitude (the entry's
/// direction supplies the sign) in the entry currency, an optional budgeting
/// [CategoryId] (ADR-0024), and an optional [Description].
public sealed record RecordFlowLine(
    decimal Amount,
    Guid? CategoryId,
    string? Description);
