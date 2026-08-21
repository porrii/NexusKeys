import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/database/vault_session.dart';
import '../../../../core/security/crypto_service.dart';
import '../../../../core/security/secure_bytes.dart';
import '../../../auth/data/datasources/auth_local_data_source.dart';
import '../../../auth/domain/entities/auth_config.dart';

/// The result of a successful [BackupService.validateImport] — everything
/// [BackupService.applyImport] needs, kept separate from validation so a
/// caller can show "contraseña correcta, ¿sobrescribir tu bóveda actual?"
/// before actually touching any files.
class ValidatedBackup {
  const ValidatedBackup({required this.authConfig, required this.vaultBytes});

  final AuthConfig authConfig;
  final Uint8List vaultBytes;
}

/// Thrown by [BackupService.validateImport] with a message safe to show
/// directly to the user — it never reveals *why* in security-sensitive
/// terms (e.g. it says "wrong password", not "HMAC verification failed"),
/// matching how [AuthRepository] treats wrong-password vs. corrupted data.
class BackupImportException implements Exception {
  const BackupImportException(this.message);

  final String message;

  @override
  String toString() => 'BackupImportException: $message';
}

/// Builds and restores the `.nexus` backup format from the spec: version,
/// minimal metadata, a checksum, and encrypted data — restorable only with
/// the master password.
///
/// The "encrypted data" is simply the vault database's own bytes, verbatim:
/// it's already a complete SQLCipher-encrypted file, so wrapping it in
/// another layer of encryption would add cost without adding security. The
/// auth header (salt, Argon2id params, verifier) travels alongside it,
/// unencrypted for the same reason [AuthConfig] itself is: its secrecy
/// doesn't matter, only its integrity under the key, which the verifier's
/// own AES-GCM MAC already guarantees.
class BackupService {
  BackupService({
    required CryptoService cryptoService,
    required AuthLocalDataSource authLocalDataSource,
    required VaultSession vaultSession,
  })  : _crypto = cryptoService,
        _authLocal = authLocalDataSource,
        // The field is private (_vaultSession) while the named constructor
        // parameter stays public (vaultSession) for callers outside this
        // library, so the initializing-formal shorthand the linter
        // suggests isn't actually available here.
        // ignore: prefer_initializing_formals
        _vaultSession = vaultSession;

  static const formatVersion = 1;

  final CryptoService _crypto;
  final AuthLocalDataSource _authLocal;
  final VaultSession _vaultSession;

  /// Builds the `.nexus` file content from whatever is currently on disk.
  /// Works whether the vault is locked or unlocked — it reads the raw
  /// files, not through a live database connection.
  Future<Uint8List> buildExport() async {
    final authConfig = await _authLocal.read();
    if (authConfig == null) {
      throw StateError('Cannot export: no master password has been configured yet.');
    }

    final vaultFile = await _vaultSession.resolveDatabaseFile();
    final vaultBytes = await vaultFile.readAsBytes();
    final checksum = await _crypto.sha512(vaultBytes);

    final envelope = <String, Object?>{
      'version': formatVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'checksum': _toHex(checksum),
      'auth': authConfig.toJson(),
      'vaultData': base64Encode(vaultBytes),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  /// Parses [fileBytes] and checks that: it's well-formed, its format
  /// version is one this app understands, its checksum matches (the file
  /// wasn't corrupted or tampered with), and [masterPassword] actually
  /// unlocks it. Throws [BackupImportException] with a user-facing message
  /// on any failure — nothing is written to disk here.
  Future<ValidatedBackup> validateImport(Uint8List fileBytes, String masterPassword) async {
    final Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(utf8.decode(fileBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw const BackupImportException('El archivo no es un backup válido de NexusKeys.');
    }

    if (envelope['version'] != formatVersion) {
      throw const BackupImportException('Este archivo fue creado con una versión incompatible.');
    }

    final Uint8List vaultBytes;
    final AuthConfig authConfig;
    try {
      vaultBytes = base64Decode(envelope['vaultData'] as String);
      authConfig = AuthConfig.fromJson(envelope['auth'] as Map<String, dynamic>);
    } on FormatException {
      throw const BackupImportException('El archivo no es un backup válido de NexusKeys.');
    }

    final expectedChecksum = envelope['checksum'] as String?;
    final actualChecksum = _toHex(await _crypto.sha512(vaultBytes));
    if (actualChecksum != expectedChecksum) {
      throw const BackupImportException('El archivo está dañado o fue modificado.');
    }

    final key = await _crypto.deriveKey(
      password: masterPassword,
      salt: authConfig.salt,
      params: authConfig.argon2Params,
    );
    try {
      await _crypto.decrypt(payload: authConfig.verifierPayload, key: key);
    } on AuthenticationFailedException {
      throw const BackupImportException('La contraseña maestra no coincide con este archivo.');
    } finally {
      wipe(key);
    }

    return ValidatedBackup(authConfig: authConfig, vaultBytes: vaultBytes);
  }

  /// Replaces the device's current auth header and vault database with
  /// [backup]'s. Irreversible — only call this after [validateImport]
  /// succeeded and the user has confirmed overwriting whatever vault (if
  /// any) already exists. Locks the session first: an open SQLCipher
  /// connection would otherwise keep the file locked (especially on
  /// Windows) while this tries to overwrite it.
  Future<void> applyImport(ValidatedBackup backup) async {
    _vaultSession.lock();
    await _authLocal.write(backup.authConfig);
    final vaultFile = await _vaultSession.resolveDatabaseFile();
    await vaultFile.writeAsBytes(backup.vaultBytes, flush: true);
  }

  String _toHex(Uint8List bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
