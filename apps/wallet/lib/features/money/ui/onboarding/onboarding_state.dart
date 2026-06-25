/// Immutable form state for the onboarding flow. Two steps back the two pieces
/// of server-owned config ADR-0013 requires before the canvas can render: the
/// first savings account (whose currency defaults the display currency) and the
/// month start day.
class OnboardingState {
  const OnboardingState({
    this.step = 0,
    this.accountName = 'Main savings',
    this.currency = 'USD',
    this.openingBalance = '',
    this.useCustomMonth = false,
    this.day = 25,
    this.appLockEnabled = true,
    this.submitting = false,
    this.error,
  });

  /// 0 = account, 1 = month start.
  final int step;
  final String accountName;
  final String currency;

  /// Raw text from the field; parsed only on submit.
  final String openingBalance;

  /// False = calendar month (start day 1); true = a day the user picks.
  final bool useCustomMonth;

  /// The chosen day when [useCustomMonth] is true (1–31).
  final int day;

  /// Whether to lock the app with biometrics (device-local, ADR-0014). Only
  /// meaningful — and only shown — when the device supports it; default on.
  final bool appLockEnabled;

  final bool submitting;
  final String? error;

  /// The month start day to persist: 1 for a calendar month, else the chosen day.
  int get effectiveMonthStartDay => useCustomMonth ? day : 1;

  OnboardingState copyWith({
    int? step,
    String? accountName,
    String? currency,
    String? openingBalance,
    bool? useCustomMonth,
    int? day,
    bool? appLockEnabled,
    bool? submitting,
    Object? error = _sentinel,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      accountName: accountName ?? this.accountName,
      currency: currency ?? this.currency,
      openingBalance: openingBalance ?? this.openingBalance,
      useCustomMonth: useCustomMonth ?? this.useCustomMonth,
      day: day ?? this.day,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      submitting: submitting ?? this.submitting,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  static const Object _sentinel = Object();
}
