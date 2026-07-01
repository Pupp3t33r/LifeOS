namespace LifeOS.Money.Api.Features.FxRates;

/// A resolved FX rate for display/conversion. <see cref="Rate"/> is the amount of
/// <see cref="Quote"/> per 1 unit of <see cref="Base"/>; <see cref="Date"/> is the
/// date the returned rate actually applies to (may be earlier than a requested date
/// under forward-fill); <see cref="Source"/> names the provider so every conversion
/// stays traceable (ADR-0015, no false precision).
public sealed record FxRateResponse(
    string Base,
    string Quote,
    decimal Rate,
    DateOnly Date,
    string Source);
