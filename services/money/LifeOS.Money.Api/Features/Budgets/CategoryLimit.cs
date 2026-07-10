using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Budgets;

/// One category's spending limit (ADR-0035) as the client sends/reads it — a list entry
/// rather than a map, so the Dart client isn't juggling Guid-keyed maps. [Amount] is in
/// the display currency (ADR-0008/0013).
public sealed record CategoryLimit(Guid CategoryId, CurrencyAmount Amount);
