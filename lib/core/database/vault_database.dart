import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'database_exceptions.dart';
import 'vault_schema.dart';

/// Una conexión abierta a la base de datos de la bóveda cifrada con
/// SQLCipher.
///
/// Cada byte en disco lo cifra el propio SQLCipher — esta clase nunca
/// maneja contenido de archivo en texto plano, solo la clave en crudo que
/// se usa para desbloquearlo.
class VaultDatabase {
  VaultDatabase._(this._db);

  final Database _db;

  /// Abre (creándola si hace falta) la base de datos cifrada en [path]
  /// usando la [key] de 32 bytes en crudo — la misma clave que Argon2id
  /// deriva de la contraseña maestra, pasada tal cual en vez de volver a
  /// derivarla con la derivación propia de SQLCipher (más débil, basada en
  /// PBKDF2).
  ///
  /// Lanza [InvalidDatabaseKeyException] si [key] no coincide con una base
  /// de datos que ya exista en [path].
  factory VaultDatabase.open(String path, Uint8List key) {
    final db = sqlite3.open(path);
    db.execute("PRAGMA key = \"x'${_toHex(key)}'\";");
    _verifyKey(db);
    _migrate(db);
    return VaultDatabase._(db);
  }

  static void _verifyKey(Database db) {
    try {
      // SQLCipher no valida la clave al abrir — solo cuando algo lee de
      // verdad la cabecera (cifrada) de la base de datos aparece una clave
      // incorrecta, como una SqliteException genérica de "file is not a
      // database".
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

  /// La conexión subyacente, para que las fuentes de datos de la feature de
  /// la bóveda ejecuten consultas contra ella una vez montada la capa CRUD.
  Database get raw => _db;

  /// Vuelve a cifrar la base de datos en el sitio bajo [newKey] — así es
  /// como cambiar la contraseña maestra vuelve a proteger la bóveda de
  /// verdad, no solo su verificador de autenticación. Requiere que la
  /// conexión ya esté abierta con su clave actual (correcta); SQLCipher
  /// hace el recifrado él mismo con `PRAGMA rekey`, así que no hay que leer
  /// nada y reescribirlo a mano.
  void rekey(Uint8List newKey) {
    _db.execute("PRAGMA rekey = \"x'${_toHex(newKey)}'\";");
  }

  void close() => _db.close();
}
