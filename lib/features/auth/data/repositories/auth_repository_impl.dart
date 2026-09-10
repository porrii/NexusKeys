import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/security/argon2_params.dart';
import '../../../../core/security/crypto_service.dart';
import '../../../../core/security/secure_bytes.dart';
import '../../domain/entities/auth_config.dart';
import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';

/// El texto plano del verificador es fijo y no secreto: se autentica bajo
/// el MAC de AES-GCM, no por mantenerse oculto, así que aquí una constante
/// vale — ver el comentario de [AuthConfig] para saber por qué es seguro.
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

  /// Coste de KDF usado al crear un verificador *nuevo* (configuración
  /// inicial o cambio de contraseña). La verificación siempre reutiliza los
  /// parámetros guardados en el [AuthConfig] existente, así que cambiar
  /// esto no invalida las bóvedas ya configuradas. Se puede sobrescribir
  /// para que los tests no tengan que pagar el coste completo de
  /// producción de 64 MiB en cada ejecución.
  final Argon2idParams _newVaultParams;

  @override
  Future<bool> isVaultInitialized() => _local.exists();

  @override
  Future<AuthResult> setupMasterPassword(String password) async {
    final salt = _crypto.randomBytes(16);
    final params = _newVaultParams;
    final key = await _crypto.deriveKey(password: password, salt: salt, params: params);

    // `key` se devuelve a quien llama dentro de AuthSuccess, así que aquí
    // no se limpia — la propiedad pasa a quien desbloquee la bóveda con
    // ella.
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
    // Borrar la cabecera de autenticación no necesita ninguna clave, así
    // que esto la limpia antes de devolver — quien llama aquí solo debe
    // comprobar éxito/fallo, nunca leer .vaultKey del resultado.
    wipe(verification.vaultKey);
    await _local.delete();
    return verification;
  }
}
