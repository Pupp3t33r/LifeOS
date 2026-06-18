import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/app/app.dart';

void main() {
  testWidgets('Wallet shell renders the month overview home', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: WalletApp()));
    await tester.pumpAndSettle();

    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Savings canvas — coming soon'), findsOneWidget);
  });
}
