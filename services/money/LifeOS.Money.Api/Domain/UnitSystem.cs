namespace LifeOS.Money.Api.Domain;

/// The owner's preferred unit system (ADR-0036) — a display-only preference stored on
/// <see cref="UserPreferences"/>. It selects which unit SYMBOL the client renders for a
/// line's <see cref="UnitDimension"/>: <see cref="Metric"/> (kg/L/m) or <see cref="Imperial"/>
/// (lb/gal/ft). Switching it relabels every quantity WITHOUT touching any stored
/// magnitude — Money performs no conversions. Default <see cref="Metric"/>.
public enum UnitSystem {
    Metric,
    Imperial,
}
