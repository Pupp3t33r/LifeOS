import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';

/// Thin wrapper over the platform biometric/device-credential prompt (`local_auth`).
/// It never enrolls or stores anything — the OS owns the fingerprint/face/PIN; this
/// just asks the OS to verify the person present and returns a boolean.
///
/// Every call is hard-guarded on [kIsWeb]: `local_auth` has no web implementation,
/// so on web these short-circuit to "unsupported / not authenticated" and the OS
/// plugin is never invoked. That is what keeps the app-lock a no-op on web.
class BiometricService {
  BiometricService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Whether this device can gate the app behind a biometric or device credential.
  /// False on web and on any device without hardware / enrolled credential.
  Future<bool> isSupported() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the OS to verify the user. `biometricOnly: false` lets the device
  /// PIN/pattern stand in when biometrics fail or aren't enrolled (ADR-0014).
  Future<bool> authenticate(String reason) async {
    if (kIsWeb) return false;
    try {
      // local_auth 3.x uses flat named options. biometricOnly:false lets the
      // device PIN/pattern stand in when biometrics fail or aren't enrolled.
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
      );
    } catch (_) {
      return false;
    }
  }
}
