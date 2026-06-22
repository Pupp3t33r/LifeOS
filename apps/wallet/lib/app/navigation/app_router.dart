import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_controller.dart';
import '../auth/sign_in_screen.dart';
import '../../features/money/ui/month_overview/month_overview_screen.dart';

/// App-wide route table. Feature screens are registered here (through the
/// shell), never by feature-to-feature wiring. Phase 1 exposes the money
/// feature plus the shell-level sign-in surface; later features add routes here.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-run [GoRouter.redirect] whenever auth state changes (sign-in/out).
  final refresh = _AuthRefresh(ref);
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
      return null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MonthOverviewScreen(),
      ),
    ],
  );
});

/// Bridges Riverpod's [authStateProvider] to a [Listenable] that GoRouter can
/// watch, so a sign-in/out re-evaluates the redirect guard immediately.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _sub = ref.listen(
      authStateProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
  }

  late final ProviderSubscription _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
