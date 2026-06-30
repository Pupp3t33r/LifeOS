using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Periods;

/// The flow ledger for one accounting period: the owner's recorded [Entries] plus
/// per-currency net [Totals] (Σ signed entry totals, one per currency present).
///
/// This is the flow read-model only — NOT the composed MonthProjection (ADR-0007),
/// which additionally needs recurring/installments/planned/budgets/review and joins
/// once those land. No FX conversion yet, so a multi-currency period returns one net
/// per currency rather than a single display-currency figure.
public sealed record PeriodFlowsResponse(
    int Year,
    int Month,
    IReadOnlyList<FlowEntryResponse> Entries,
    IReadOnlyList<CurrencyAmount> Totals);
