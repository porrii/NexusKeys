import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/entities/auth_config.dart';

/// Guarda la cabecera de autenticación (salt, parámetros de Argon2id,
/// verificador cifrado) como un pequeño archivo JSON en el directorio de
/// documentos de la app.
///
/// Este archivo *no* es secreto — su confidencialidad no importa, solo su
/// integridad bajo la clave derivada (garantizada por el MAC de AES-GCM).
/// Mantenerlo como un archivo plano y portable (en vez de en el keystore
/// del SO) significa que una bóveda se puede mover a otro dispositivo y
/// desbloquear solo con la contraseña maestra, acorde con el diseño de la
/// app: sin conexión y sin sincronización.
class AuthLocalDataSource {
  AuthLocalDataSource({this.overrideDirectory});

  static const _fileName = 'auth.json';

  /// Solo lo fijan los tests, para redirigir la cabecera de autenticación a
  /// un directorio temporal en vez del directorio real de soporte de la
  /// app.
  final Directory? overrideDirectory;

  Future<File> _authFile() async {
    final dir = overrideDirectory ?? await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  Future<bool> exists() async => (await _authFile()).exists();

  Future<AuthConfig?> read() async {
    final file = await _authFile();
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    return AuthConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> write(AuthConfig config) async {
    final file = await _authFile();
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode(config.toJson()));
  }

  Future<void> delete() async {
    final file = await _authFile();
    if (await file.exists()) await file.delete();
  }
}
