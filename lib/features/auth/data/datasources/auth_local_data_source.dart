import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/entities/auth_config.dart';

/// Persists the auth header (salt, Argon2id params, encrypted verifier) as
/// a small JSON file in the app's documents directory.
///
/// This file is *not* secret — its confidentiality doesn't matter, only its
/// integrity under the derived key (enforced by AES-GCM's MAC). Keeping it
/// as a plain, portable file (rather than in the OS keystore) means a
/// vault can be moved to a new device and unlocked with the master
/// password alone, per the app's offline-only, sync-free design.
class AuthLocalDataSource {
  AuthLocalDataSource({this.overrideDirectory});

  static const _fileName = 'auth.json';

  /// Set only by tests, to redirect the auth header to a temp directory
  /// instead of the real app-support directory.
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
