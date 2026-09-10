import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/services/vault_key_store.dart';

/// Implementación de [VaultKeyStore] respaldada por el Keystore del SO,
/// usando `AndroidOptions.biometric(enforceBiometrics: true)` de
/// flutter_secure_storage: la clave AES del Keystore que protege esta
/// entrada se genera con `setUserAuthenticationRequired(true)`, así que
/// leerla o escribirla hace que el lado nativo del plugin muestre el
/// `BiometricPrompt` real del SO (ligado a la clave con un `CryptoObject`)
/// y solo continúe cuando ese tenga éxito — lo garantiza el
/// Keystore/hardware, no una comprobación a nivel de app que algo con un
/// depurador enganchado pudiera saltarse.
///
/// En Windows esto recae en el almacenamiento por defecto de
/// `flutter_secure_storage` respaldado por DPAPI (sin barrera biométrica —
/// este plugin no expone el control de Windows Hello), ya que ahí de todas
/// formas no se ofrece desbloqueo biométrico (ver `BiometricService`, que
/// informa del dispositivo como no compatible en Windows).
class SecureVaultKeyStore implements VaultKeyStore {
  SecureVaultKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions.biometric(
                enforceBiometrics: true,
                biometricPromptTitle: 'Confirmar identidad',
                biometricPromptSubtitle: 'Usa tu huella dactilar para continuar',
                biometricPromptNegativeButton: 'Cancelar',
              ),
            );

  static const _storageKey = 'nexuskeys.biometric_vault_key';

  final FlutterSecureStorage _storage;

  bool _hasWarmedUpCipher = false;

  @override
  bool get hasWarmedUpCipher => _hasWarmedUpCipher;

  @override
  Future<bool> get hasStoredKey async {
    try {
      return await _storage.containsKey(key: _storageKey);
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> save(Uint8List vaultKey) async {
    await _storage.write(key: _storageKey, value: base64Encode(vaultKey));
    _hasWarmedUpCipher = true;
  }

  /// Null tanto cuando no se ha guardado nada como cuando el prompt
  /// biométrico nativo se canceló o falló — [BiometricPromptPage] trata
  /// ambos casos igual (deja al usuario reintentar o volver a la
  /// contraseña).
  @override
  Future<Uint8List?> read() async {
    try {
      final encoded = await _storage.read(key: _storageKey);
      // Llegar a esta línea significa que la propia autenticación del
      // plugin (si iba a preguntar) ya tuvo éxito — una PlatformException
      // lanzada abajo significa que no, así que esto se salta y el
      // siguiente read() puede volver a intentar un prompt nativo nuevo.
      _hasWarmedUpCipher = true;
      if (encoded == null) return null;
      return base64Decode(encoded);
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> clear() => _storage.delete(key: _storageKey);
}
