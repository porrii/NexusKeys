import '../entities/auth_result.dart';

/// Master-password setup and verification. Implementations must never
/// persist the password itself or the raw derived key — only the salt, KDF
/// params and an authenticated verifier (see [AuthConfig]).
abstract interface class AuthRepository {
  /// Whether a master password has already been configured on this device.
  Future<bool> isVaultInitialized();

  /// First-time setup: generates a random salt, derives a key from
  /// [password] with Argon2id, and persists the auth header. Fails with
  /// [AuthFailureReason.vaultNotInitialized] never happens here — setup
  /// always succeeds unless the underlying storage write fails, in which
  /// case the write exception propagates.
  Future<AuthResult> setupMasterPassword(String password);

  /// Re-derives the key from [password] and checks it against the stored
  /// verifier.
  Future<AuthResult> verifyMasterPassword(String password);

  /// Re-encrypts the stored verifier under a key derived from
  /// [newPassword], after confirming [currentPassword] is correct.
  /// Returns [AuthFailureReason.wrongPassword] without changing anything if
  /// [currentPassword] doesn't match.
  Future<AuthResult> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Erases the auth header (salt, KDF params, verifier) after confirming
  /// [password] is correct — the vault's own database file is a separate
  /// concern, deleted by the caller via [VaultSession] once this succeeds.
  /// Returns [AuthFailureReason.wrongPassword] without deleting anything if
  /// [password] doesn't match.
  Future<AuthResult> deleteVault({required String password});
}
