import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/app/app.dart';
import 'package:wallet/app/auth/auth_controller.dart';
import 'package:wallet/app/auth/auth_state.dart';

void main() {
  testWidgets('unauthenticated users are routed to the sign-in surface',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Force a signed-out session so the router guard sends us to /sign-in
          // without touching Keycloak or the network.
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const AuthState(status: AuthStatus.unauthenticated),
            ),
          ),
        ],
        child: const WalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The hosted-auth landing, not the money home, is shown.
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Savings canvas — coming soon'), findsNothing);
  });
}
