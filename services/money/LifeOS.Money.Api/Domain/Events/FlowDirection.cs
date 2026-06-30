namespace LifeOS.Money.Api.Domain.Events;

/// Whether a flow brings money in or out (ADR-0016). Entry-level: every line in a
/// <see cref="FlowRecorded"/> shares the entry's direction. Mixed-sign entries
/// (e.g. a receipt with an overall discount) are a deferred concern — see the ADR
/// README — and would move the sign onto the line.
public enum FlowDirection {
    In,
    Out,
}
