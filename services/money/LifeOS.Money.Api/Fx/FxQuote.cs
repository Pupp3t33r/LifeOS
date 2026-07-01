namespace LifeOS.Money.Api.Fx;

/// One rate observation returned by an <see cref="IFxRateSource"/> before it is
/// persisted as a <c>FxRate</c> document. <see cref="Rate"/> is the amount of
/// <see cref="Quote"/> per 1 unit of <see cref="Base"/>.
public sealed record FxQuote(string Base, string Quote, DateOnly Date, decimal Rate, string Source);
