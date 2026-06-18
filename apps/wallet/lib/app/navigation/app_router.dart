import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/money/ui/month_overview/month_overview_screen.dart';

/// App-wide route table. Feature screens are registered here (through the
/// shell), never by feature-to-feature wiring. Phase 1 exposes only the
/// money feature; later features add their routes here.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MonthOverviewScreen(),
      ),
    ],
  );
});
