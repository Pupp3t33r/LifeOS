import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../security/application/security_providers.dart';
import '../../application/preferences_providers.dart';
import '../../data/preferences_repository.dart';
import 'onboarding_state.dart';

/// Drives the onboarding form: holds the in-progress answers and, on finish,
/// writes them to the Money service (open account → set display currency → set
/// month start day) then re-gates the router by refreshing [preferencesProvider].
class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void setAccountName(String value) => state = state.copyWith(accountName: value);
  void setCurrency(String value) => state = state.copyWith(currency: value);
  void setOpeningBalance(String value) => state = state.copyWith(openingBalance: value);
  void setDay(int value) => state = state.copyWith(day: value);

  void useCalendarMonth() => state = state.copyWith(useCustomMonth: false);
  void useCustomMonth() => state = state.copyWith(useCustomMonth: true);

  void setAppLockEnabled(bool value) => state = state.copyWith(appLockEnabled: value);

  /// Advance a step. The screen only calls this when a next step exists (the last
  /// step depends on whether the device supports the biometric app-lock).
  void next() => state = state.copyWith(step: state.step + 1);

  void back() {
    if (state.step > 0) state = state.copyWith(step: state.step - 1);
  }

  /// Persists the collected config. Returns true on success; on failure leaves
  /// the form intact with [OnboardingState.error] set to [failureMessage] (passed
  /// in already-localized by the caller, which has the BuildContext) so the user
  /// can retry.
  Future<bool> submit(String failureMessage) async {
    if (state.submitting) return false;
    state = state.copyWith(submitting: true, error: null);

    final repo = ref.read(preferencesRepositoryProvider);
    try {
      await repo.openAccount(
        name: state.accountName.trim().isEmpty ? 'Main savings' : state.accountName.trim(),
        currency: state.currency,
        openingBalance: _parseAmount(state.openingBalance),
      );
      await repo.setDisplayCurrency(state.currency);
      await repo.setMonthStartDay(state.effectiveMonthStartDay);

      // Persist the device-local app-lock choice (only where the device supports it).
      if (await ref.read(biometricSupportedProvider.future)) {
        await ref.read(appLockStoreProvider).setEnabled(state.appLockEnabled);
        ref.invalidate(appLockEnabledProvider);
      }

      // Re-fetch so the router gate sees onboarding as complete and routes home.
      ref.invalidate(preferencesProvider);
      await ref.read(preferencesProvider.future);
      return true;
    } catch (error) {
      state = state.copyWith(submitting: false, error: failureMessage);
      return false;
    }
  }

  static double? _parseAmount(String raw) {
    final cleaned = raw.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(OnboardingController.new);
