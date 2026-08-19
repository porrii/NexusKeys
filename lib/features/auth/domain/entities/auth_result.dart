import 'dart:typed_data';

/// Outcome of a master-password verification or setup attempt.
sealed class AuthResult {
  const AuthResult();
}

/// The password was correct (or setup succeeded). [vaultKey] is the raw
/// 32-byte key derived from it — callers must wipe it (see `secure_bytes.dart`)
/// once they've used it to unlock the encrypted database.
class AuthSuccess extends AuthResult {
  const AuthSuccess(this.vaultKey);

  final Uint8List vaultKey;
}

class AuthFailure extends AuthResult {
  const AuthFailure(this.reason);

  final AuthFailureReason reason;
}

enum AuthFailureReason {
  /// No master password has been set up on this device yet.
  vaultNotInitialized,

  /// The password didn't decrypt the stored verifier.
  wrongPassword,

  /// The auth header exists but couldn't be parsed — most likely a
  /// corrupted or truncated file, not a wrong password.
  corruptedAuthData,
}
