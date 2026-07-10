import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/auth/auth_controller.dart';
import '../../../app/data/outbox_repository.dart';
import '../data/wishlist_repository.dart';
import '../domain/wishlist_item.dart';

/// The outbox's pending/syncing rows — re-emits on every change, so the wishlist read
/// revalidates when a create/edit/delete op is queued or drains.
final _pendingWishlistOpsProvider = StreamProvider((ref) =>
    ref.watch(outboxRepositoryProvider).watchPending());

/// The caller's whole wishlist (ADR-0022/0034), auth-gated. Re-fetches whenever the
/// outbox changes, so a just-created want appears once its op drains and a planned/paid
/// one reflects its new derived status on the next revalidate.
final wishlistProvider = FutureProvider<Wishlist>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null || !auth.isAuthenticated) {
    return Future.value(const Wishlist(items: [], packages: []));
  }
  ref.watch(_pendingWishlistOpsProvider); // revalidate on outbox change
  return ref.watch(wishlistRepositoryProvider).get();
});

/// The Board try-on tray's contents: wants the tray should show (idle + all reusables),
/// sorted by name (ADR-0005 §4/§9).
final wishlistTrayProvider = Provider<List<WishlistItem>>((ref) {
  final wishlist = ref.watch(wishlistProvider).value;
  if (wishlist == null) return const [];
  final tray = wishlist.items.where((x) => x.isTrayEligible).toList()
    ..sort((a, b) => (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()));
  return tray;
});
