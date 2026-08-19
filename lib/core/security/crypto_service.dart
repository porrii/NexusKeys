import 'dart:typed_data';

import 'argon2_params.dart';

/// The result of an AES-256-GCM encryption: everything needed to decrypt,
/// none of it secret except [cipherText] (the nonce and MAC are safe to
/// store alongside it).
class EncryptedPayload {
  const EncryptedPayload({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final Uint8List nonce;
  final Uint8List cipherText;
  final Uint8List mac;
}

/// Thrown by [CryptoService.decrypt] when the MAC doesn't match — either the
/// key is wrong or the data was tampered with. Callers must not distinguish
/// between those two cases in user-facing messages.
class AuthenticationFailedException implements Exception {
  const AuthenticationFailedException();

  @override
  String toString() => 'AuthenticationFailedException: decryption failed integrity check';
}

/// Every cryptographic primitive the app needs, isolated behind one
/// interface so the rest of the codebase never touches `package:cryptography`
/// directly. Backed by [CryptoServiceImpl].
abstract interface class CryptoService {
  /// Derives a 32-byte key from [password] and [salt] using Argon2id.
  /// The same inputs always produce the same output — this is what makes
  /// master password verification possible without storing the password.
  Future<Uint8List> deriveKey({
    required String password,
    required Uint8List salt,
    required Argon2idParams params,
  });

  /// Cryptographically secure random bytes (CSPRNG), suitable for salts,
  /// nonces and encryption keys.
  Uint8List randomBytes(int length);

  /// Encrypts [plainText] with AES-256-GCM under [key] (must be 32 bytes).
  /// A fresh random nonce is generated for every call.
  Future<EncryptedPayload> encrypt({
    required Uint8List plainText,
    required Uint8List key,
  });

  /// Decrypts a payload produced by [encrypt]. Throws
  /// [AuthenticationFailedException] if [key] is wrong or the data was
  /// tampered with.
  Future<Uint8List> decrypt({
    required EncryptedPayload payload,
    required Uint8List key,
  });

  /// SHA-512 digest, used for non-secret integrity checksums (e.g. the
  /// `.nexus` export format).
  Future<Uint8List> sha512(Uint8List data);
}
