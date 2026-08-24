import 'dart:typed_data';

/// Persists the derived vault key for biometric unlock, so that path can
/// skip re-deriving it from the master password. Implementations must back
/// this with OS Keystore-backed storage (never plain prefs/registry) — see
/// `SecureVaultKeyStore`.
///
/// Reading this store is not itself gated by biometrics; the app layer
/// always calls `BiometricService.authenticate` first and only reaches
/// [read] after that succeeds (see `BiometricPromptPage`). That's a
/// deliberate, documented trade-off: true crypto-level biometric gating
/// would require a native Android Keystore key with
/// `setUserAuthenticationRequired` wired through `BiometricPrompt`'s
/// `CryptoObject`, which is out of scope here.
abstract interface class VaultKeyStore {
  Future<bool> get hasStoredKey;

  Future<void> save(Uint8List vaultKey);

  /// Null if nothing has been stored (or it was cleared).
  Future<Uint8List?> read();

  Future<void> clear();
}
