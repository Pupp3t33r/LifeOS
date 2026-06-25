namespace LifeOS.Money.Api.Features.UserPreferences;

/// The owner's current Money configuration (ADR-0013). <see cref="OnboardingComplete"/>
/// is a convenience derived from <see cref="DisplayCurrency"/> being set — the
/// single signal the Wallet uses to decide whether to show onboarding.
public sealed record PreferencesResponse(
    int MonthStartDay,
    string? DisplayCurrency,
    bool OnboardingComplete);
