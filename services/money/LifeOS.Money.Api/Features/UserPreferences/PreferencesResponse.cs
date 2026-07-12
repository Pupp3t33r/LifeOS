using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.UserPreferences;

/// The owner's current Money configuration (ADR-0013/0036). <see cref="OnboardingComplete"/>
/// is a convenience derived from <see cref="DisplayCurrency"/> being set — the
/// single signal the Wallet uses to decide whether to show onboarding. <see cref="UnitSystem"/>
/// is the display-only unit-symbol selector (ADR-0036).
public sealed record PreferencesResponse(
    int MonthStartDay,
    string? DisplayCurrency,
    UnitSystem UnitSystem,
    bool OnboardingComplete);
