/// Wraps the platform's own biometric prompt (Android BiometricPrompt,
/// Windows Hello). NexusKeys never gets direct sensor access — no Flutter
/// app does — so [authenticate] is only ever "ask the OS to show its native
/// dialog and tell us whether it succeeded."
abstract interface class BiometricService {
  /// Whether this device has usable biometric hardware with at least one
  /// credential enrolled. False on emulators/devices with nothing set up.
  Future<bool> isDeviceSupported();

  /// Shows the OS biometric prompt with [reason] as the rationale text.
  /// Returns whether the user authenticated successfully; false covers both
  /// "cancelled" and "failed" since neither should be treated differently
  /// by callers here.
  Future<bool> authenticate({required String reason});
}
