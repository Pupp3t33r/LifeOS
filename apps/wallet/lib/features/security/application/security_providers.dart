import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/app_lock_store.dart';
import '../data/biometric_service.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) => BiometricService());

final appLockStoreProvider = Provider<AppLockStore>((ref) => AppLockStore());

/// Whether this device can offer the biometric app-lock. False on web (the
/// service short-circuits), so the onboarding toggle is hidden and the lock gate
/// stays a passthrough.
final biometricSupportedProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricServiceProvider).isSupported(),
);

/// The device-local "app-lock enabled" preference. Invalidate after writing it
/// (e.g. at the end of onboarding) so the lock gate re-evaluates.
final appLockEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(appLockStoreProvider).isEnabled(),
);
