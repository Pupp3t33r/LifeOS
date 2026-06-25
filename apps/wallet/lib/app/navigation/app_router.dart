import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_controller.dart';
import '../auth/sign_in_screen.dart';
import '../../features/money/application/preferences_providers.dart';
import '../../features/money/ui/onboarding/onboarding_screen.dart';
import '../../features/money/ui/month_overview/month_overview_screen.dart';

/// App-wide route table. Feature screens are registered here (through the
/// shell), never by feature-to-feature wiring. Phase 1 exposes the money
/// feature plus the shell-level sign-in surface; later features add routes here.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-run [GoRouter.redirect] whenever auth state OR onboarding state changes.
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final isAuthed =
          ref.read(authStateProvider).value?.isAuthenticated ?? false;
      final atSignIn = state.matchedLocation == '/sign-in';

      // Unknown/loading session is treated as signed-out; the sign-in screen
      // renders its own spinner while [authStateProvider] initializes.
      if (!isAuthed) return atSignIn ? null : '/sign-in';
      if (atSignIn) return '/';

      // Signed in: gate on onboarding. A loaded preferences value with no
      // display currency means setup isn't done (Money ADR-0013) → onboarding.
      // While preferences load (or error), don't trap the user; the placeholder
      // home tolerates it and the gate re-runs when the value resolves.
      final atOnboarding = state.matchedLocation == '/onboarding';
      return ref.read(preferencesProvider).maybeWhen(
            data: (prefs) {
              if (!prefs.onboardingComplete) return atOnboarding ? null : '/onboarding';
              if (atOnboarding) return '/';
              return null;
            },
            orElse: () => null,
          );
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MonthOverviewScreen(),
      ),
    ],
  );
});

/// Bridges the Riverpod providers the redirect guard depends on — auth and
/// onboarding state — to a [Listenable] GoRouter can watch, so a sign-in/out or
/// a resolved/changed preferences value re-evaluates the guard immediately.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    _authSub = ref.listen(
      authStateProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
    _prefsSub = ref.listen(
      preferencesProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
  }

  late final ProviderSubscription _authSub;
  late final ProviderSubscription _prefsSub;

  @override
  void dispose() {
    _authSub.close();
    _prefsSub.close();
    super.dispose();
  }
}
