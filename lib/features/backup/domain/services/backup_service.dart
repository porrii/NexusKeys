import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/database/vault_session.dart';
import '../../../../core/security/crypto_service.dart';
import '../../../../core/security/secure_bytes.dart';
import '../../../auth/data/datasources/auth_local_data_source.dart';
import '../../../auth/domain/entities/auth_config.dart';

/// El resultado de un [BackupService.validateImport] correcto — todo lo
/// que necesita [BackupService.applyImport], separado de la validación
/// para que quien llama pueda mostrar "contraseña correcta, ¿sobrescribir
/// tu bóveda actual?" antes de tocar ningún archivo.
class ValidatedBackup {
  const ValidatedBackup({required this.authConfig, required this.vaultBytes});

  final AuthConfig authConfig;
  final Uint8List vaultBytes;
}

/// La lanza [BackupService.validateImport] con un mensaje seguro de
/// mostrar directamente al usuario — nunca revela el *porqué* en términos
/// sensibles de seguridad (p. ej. dice "contraseña incorrecta", no "falló
/// la verificación del HMAC"), igual que [AuthRepository] trata contraseña
/// incorrecta frente a datos corruptos.
class BackupImportException implements Exception {
  const BackupImportException(this.message);

  final String message;

  @override
  String toString() => 'BackupImportException: $message';
}

/// Construye y restaura el formato de backup `.nexus` de la
/// especificación: versión, metadatos mínimos, un checksum y datos
/// cifrados — restaurable solo con la contraseña maestra.
///
/// Los "datos cifrados" son simplemente los propios bytes de la base de
/// datos de la bóveda, tal cual: ya es un archivo completo cifrado con
/// SQLCipher, así que envolverlo en otra capa de cifrado añadiría coste
/// sin añadir seguridad. La cabecera de autenticación (salt, parámetros de
/// Argon2id, verificador) viaja junto a ellos, sin cifrar por la misma
/// razón que el propio [AuthConfig]: su secreto no importa, solo su
/// integridad bajo la clave, que el propio MAC de AES-GCM del verificador
/// ya garantiza.
class BackupService {
  BackupService({
    required CryptoService cryptoService,
    required AuthLocalDataSource authLocalDataSource,
    required VaultSession vaultSession,
  })  : _crypto = cryptoService,
        _authLocal = authLocalDataSource,
        // El campo es privado (_vaultSession) mientras que el parámetro con
        // nombre del constructor sigue siendo público (vaultSession) para
        // quien llame desde fuera de esta librería, así que el atajo de
        // "initializing formal" que sugiere el linter no está disponible
        // aquí de verdad.
        // ignore: prefer_initializing_formals
        _vaultSession = vaultSession;

  static const formatVersion = 1;

  final CryptoService _crypto;
  final AuthLocalDataSource _authLocal;
  final VaultSession _vaultSession;

  /// Construye el contenido del archivo `.nexus` a partir de lo que haya en
  /// disco en ese momento. Funciona tanto si la bóveda está bloqueada como
  /// desbloqueada — lee los archivos en crudo, no a través de una conexión
  /// viva a la base de datos.
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

  /// Parsea [fileBytes] y comprueba que: está bien formado, su versión de
  /// formato es una que esta app entiende, su checksum coincide (el
  /// archivo no se corrompió ni se manipuló) y [masterPassword] lo
  /// desbloquea de verdad. Lanza [BackupImportException] con un mensaje de
  /// cara al usuario ante cualquier fallo — aquí no se escribe nada en
  /// disco.
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

  /// Reemplaza la cabecera de autenticación y la base de datos de la
  /// bóveda actuales del dispositivo por las de [backup]. Irreversible —
  /// solo llámalo después de un [validateImport] correcto y de que el
  /// usuario haya confirmado sobrescribir la bóveda que ya exista (si la
  /// hay). Bloquea la sesión primero: si no, una conexión SQLCipher
  /// abierta mantendría el archivo bloqueado (sobre todo en Windows)
  /// mientras esto intenta sobrescribirlo.
  Future<void> applyImport(ValidatedBackup backup) async {
    _vaultSession.lock();
    await _authLocal.write(backup.authConfig);
    final vaultFile = await _vaultSession.resolveDatabaseFile();
    await vaultFile.writeAsBytes(backup.vaultBytes, flush: true);
  }

  String _toHex(Uint8List bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
