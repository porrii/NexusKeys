import 'dart:typed_data';

/// Persists the derived vault key for biometric unlock, so that path can
/// skip re-deriving it from the master password. Implementations must back
/// this with OS Keystore-backed storage (never plain prefs/registry) — see
/// `SecureVaultKeyStore`, which backs [read]/[save] with a Keystore key
/// requiring real biometric authentication to decrypt/encrypt.
///
/// [read] is *not* reliably gated by that on its own, though: on Android,
/// the underlying storage only actually shows the native prompt the first
/// time this process touches it, then keeps the unlocked cipher in memory
/// and reuses it silently for the rest of the process — see
/// [hasWarmedUpCipher]. `BiometricPromptPage` is what makes every attempt
/// actually ask, by calling `BiometricService.authenticate` itself first
/// whenever [hasWarmedUpCipher] says [read] wouldn't ask on its own.
abstract interface class VaultKeyStore {
  Future<bool> get hasStoredKey;

  Future<void> save(Uint8List vaultKey);

  /// Null if nothing has been stored (or it was cleared).
  Future<Uint8List?> read();

  Future<void> clear();

  /// True once [read] or [save] has already made the underlying storage
  /// authenticate at least once during this app process. Always false at
  /// cold start, and stays false again after the *next* cold start — this
  /// tracks the plugin's own in-memory cipher cache, not anything
  /// persisted. See the class doc for why `BiometricPromptPage` needs it.
  bool get hasWarmedUpCipher;
}
