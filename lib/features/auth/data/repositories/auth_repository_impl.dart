import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/security/argon2_params.dart';
import '../../../../core/security/crypto_service.dart';
import '../../../../core/security/secure_bytes.dart';
import '../../domain/entities/auth_config.dart';
import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';

/// The verifier plaintext is fixed and non-secret: it authenticates under
/// AES-GCM's MAC, not by being kept hidden, so a constant is fine here — see
/// [AuthConfig]'s doc comment for why that's safe.
final Uint8List _verifierPlainText = Uint8List.fromList(utf8.encode('nexuskeys.verifier.v1'));

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required CryptoService cryptoService,
    required AuthLocalDataSource localDataSource,
    Argon2idParams? argon2Params,
  })  : _crypto = cryptoService,
        _local = localDataSource,
        _newVaultParams = argon2Params ?? Argon2idParams.recommended();

  final CryptoService _crypto;
  final AuthLocalDataSource _local;

  /// KDF cost used when creating a *new* verifier (setup or password
  /// change). Verification always re-uses whatever params are stored in
  /// the existing [AuthConfig], so changing this doesn't invalidate
  /// already-configured vaults. Overridable so tests don't have to pay for
  /// the full 64 MiB production cost on every run.
  final Argon2idParams _newVaultParams;

  @override
  Future<bool> isVaultInitialized() => _local.exists();

  @override
  Future<AuthResult> setupMasterPassword(String password) async {
    final salt = _crypto.randomBytes(16);
    final params = _newVaultParams;
    final key = await _crypto.deriveKey(password: password, salt: salt, params: params);

    // `key` is handed back to the caller in AuthSuccess, so it isn't wiped
    // here — ownership passes to whoever unlocks the vault with it.
    final verifier = await _crypto.encrypt(plainText: _verifierPlainText, key: key);
    await _local.write(AuthConfig(
      salt: salt,
      argon2Params: params,
      verifierNonce: verifier.nonce,
      verifierCipherText: verifier.cipherText,
      verifierMac: verifier.mac,
    ));
    return AuthSuccess(key);
  }

  @override
  Future<AuthResult> verifyMasterPassword(String password) async {
    final AuthConfig config;
    try {
      final loaded = await _local.read();
      if (loaded == null) return const AuthFailure(AuthFailureReason.vaultNotInitialized);
      config = loaded;
    } on FormatException {
      return const AuthFailure(AuthFailureReason.corruptedAuthData);
    }

    final key = await _crypto.deriveKey(
      password: password,
      salt: config.salt,
      params: config.argon2Params,
    );

    try {
      await _crypto.decrypt(payload: config.verifierPayload, key: key);
      return AuthSuccess(key);
    } on AuthenticationFailedException {
      wipe(key);
      return const AuthFailure(AuthFailureReason.wrongPassword);
    }
  }

  @override
  Future<AuthResult> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final verification = await verifyMasterPassword(currentPassword);
    if (verification is! AuthSuccess) return verification;
    wipe(verification.vaultKey);
    return setupMasterPassword(newPassword);
  }

  @override
  Future<AuthResult> deleteVault({required String password}) async {
    final verification = await verifyMasterPassword(password);
    if (verification is! AuthSuccess) return verification;
    // Deleting the auth header needs no key at all, so this wipes it before
    // returning — callers here should only check success/failure, never
    // read .vaultKey off the result.
    wipe(verification.vaultKey);
    await _local.delete();
    return verification;
  }
}
