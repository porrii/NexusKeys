import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/services/vault_key_store.dart';

/// OS Keystore-backed implementation of [VaultKeyStore], using
/// flutter_secure_storage's `AndroidOptions.biometric(enforceBiometrics:
/// true)`: the Keystore AES key protecting this entry is generated with
/// `setUserAuthenticationRequired(true)`, so reading or writing it makes
/// the plugin's native side show the real OS `BiometricPrompt` itself
/// (bound to the key via a `CryptoObject`) and only proceed once that
/// succeeds — this is enforced by the Keystore/hardware, not by an app-level
/// check that something with a debugger attached could skip.
///
/// On Windows this falls back to `flutter_secure_storage`'s DPAPI-backed
/// default storage (no biometric gate — Windows Hello gating isn't exposed
/// by this plugin), since biometric unlock isn't offered there anyway (see
/// `BiometricService`, which reports the device as unsupported on Windows).
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

  /// Null both when nothing has been stored and when the native biometric
  /// prompt was cancelled or failed — [BiometricPromptPage] treats those
  /// the same way (let the user retry or fall back to the password).
  @override
  Future<Uint8List?> read() async {
    try {
      final encoded = await _storage.read(key: _storageKey);
      // Reaching this line at all means the plugin's own authentication
      // (if it was going to ask) already succeeded — a thrown
      // PlatformException below means it didn't, so this is skipped and
      // the very next read() still gets to try a fresh native prompt.
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
