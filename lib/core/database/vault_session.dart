import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'vault_database.dart';

/// Owns the lifetime of the currently-open [VaultDatabase], if any.
///
/// Registered as a single long-lived instance in the service locator so
/// every layer agrees on whether the vault is unlocked right now: the auth
/// flow calls [unlock]/[lock], and once the vault CRUD feature exists it
/// reads [database] to run queries — nobody re-opens the file independently
/// or holds their own copy of the key.
class VaultSession {
  VaultSession({this.overrideDirectory});

  static const _fileName = 'vault.db';

  /// Set only by tests, to redirect the vault database to a temp directory
  /// instead of the real app-support directory.
  final Directory? overrideDirectory;

  VaultDatabase? _database;

  bool get isUnlocked => _database != null;

  /// The active connection. Throws [StateError] if the vault is locked —
  /// callers only reach this after [unlock] succeeded, so a null check
  /// here would just hide a real bug in the caller.
  VaultDatabase get database {
    final db = _database;
    if (db == null) throw StateError('VaultSession.database read while the vault is locked');
    return db;
  }

  Future<void> unlock(Uint8List key) async {
    _database?.close();
    final dir = overrideDirectory ?? await getApplicationSupportDirectory();
    _database = VaultDatabase.open('${dir.path}${Platform.pathSeparator}$_fileName', key);
  }

  void lock() {
    _database?.close();
    _database = null;
  }
}
