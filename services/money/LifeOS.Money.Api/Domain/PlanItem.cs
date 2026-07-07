namespace LifeOS.Money.Api.Domain;

/// A line-item of a Materialized plan's contents (ADR-0029) — *what* the plan buys,
/// carrying no cost. A plan is one all-in, discounted purchase whose real total is
/// its payments (Σ `ScheduleLines`), so an item is priceless: a [Description], an
/// optional informational [ReferenceValue] (an MSRP-style figure, never validated or
/// summed — the input a future Phase-3 net-worth valuation weights by), a budgeting
/// [CategoryId], and a Phase-2 [WishlistItemId] link (ADR-0019/0022). Distinct from
/// [Line], which carries a mandatory signed amount for actual flows and Live estimates.
public sealed record PlanItem(
    string? Description,
    CurrencyAmount? ReferenceValue,
    Guid? CategoryId,
    Guid? WishlistItemId);
