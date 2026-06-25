import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/auth/auth_controller.dart';
import '../data/preferences_repository.dart';
import '../domain/user_preferences.dart';

/// The current user's Money preferences (ADR-0013). The router gates onboarding
/// on this: a loaded value with `onboardingComplete == false` sends the user to
/// the onboarding flow. Invalidate it after writing preferences to re-gate.
///
/// Gated on auth: fetching while signed out would only 401, so when there is no
/// authenticated session this yields defaults (the redirect sends unauthenticated
/// users to sign-in before the onboarding gate is consulted). Watching the auth
/// state also re-fetches automatically once the user signs in.
final preferencesProvider = FutureProvider<UserPreferences>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null || !auth.isAuthenticated) {
    return Future.value(UserPreferences.defaults);
  }
  return ref.watch(preferencesRepositoryProvider).fetch();
});
