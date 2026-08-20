import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'database_exceptions.dart';
import 'vault_schema.dart';

/// An open connection to the SQLCipher-encrypted vault database.
///
/// Every byte on disk is encrypted by SQLCipher itself — this class never
/// handles plaintext file content, only the raw key used to unlock it.
class VaultDatabase {
  VaultDatabase._(this._db);

  final Database _db;

  /// Opens (creating if needed) the encrypted database at [path] using the
  /// raw 32-byte [key] — the same key Argon2id derives from the master
  /// password, passed straight through rather than re-derived by
  /// SQLCipher's own (weaker, PBKDF2-based) key derivation.
  ///
  /// Throws [InvalidDatabaseKeyException] if [key] doesn't match a
  /// database that already exists at [path].
  factory VaultDatabase.open(String path, Uint8List key) {
    final db = sqlite3.open(path);
    db.execute("PRAGMA key = \"x'${_toHex(key)}'\";");
    _verifyKey(db);
    _migrate(db);
    return VaultDatabase._(db);
  }

  static void _verifyKey(Database db) {
    try {
      // SQLCipher doesn't validate the key on open — only once something
      // actually reads the (encrypted) database header does a wrong key
      // surface, as a generic "file is not a database" SqliteException.
      db.select('SELECT count(*) FROM sqlite_master;');
    } on SqliteException {
      db.close();
      throw const InvalidDatabaseKeyException();
    }
  }

  static void _migrate(Database db) {
    final currentVersion = db.select('PRAGMA user_version;').first['user_version'] as int;
    final statements = VaultSchema.migrationFrom(currentVersion);
    if (statements.isEmpty) return;

    db.execute('BEGIN;');
    try {
      for (final statement in statements) {
        db.execute(statement);
      }
      db.execute('PRAGMA user_version = ${VaultSchema.version};');
      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  static String _toHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// The underlying connection, for the vault feature's data sources to
  /// run queries against once the CRUD layer is built.
  Database get raw => _db;

  void close() => _db.close();
}
