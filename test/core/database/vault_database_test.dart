import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/database/database_exceptions.dart';
import 'package:nexuskeys/core/database/vault_database.dart';
import 'package:nexuskeys/core/database/vault_schema.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  final key = Uint8List.fromList(List.generate(32, (i) => i));
  final otherKey = Uint8List.fromList(List.generate(32, (i) => 255 - i));

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nexuskeys_vault_db_test_');
    dbPath = '${tempDir.path}${Platform.pathSeparator}vault.db';
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('opening a new path creates the vault_items table', () {
    final db = VaultDatabase.open(dbPath, key);
    addTearDown(db.close);

    final tables = db.raw.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='vault_items';",
    );

    expect(tables.length, 1);
  });

  test('opening a new path creates the categories table', () {
    final db = VaultDatabase.open(dbPath, key);
    addTearDown(db.close);

    final tables = db.raw.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='categories';",
    );

    expect(tables.length, 1);
  });

  test('a database left at schema version 1 gains the categories table on reopen', () {
    // Simula una instalación anterior a la tabla categories: crea solo lo
    // que tenía la versión 1, y marca user_version = 1 a mano en vez de
    // pasar por VaultDatabase.open (que ya la crearía).
    final legacy = VaultDatabase.open(dbPath, key);
    legacy.raw.execute(VaultSchema.createVaultItemsTable);
    for (final index in VaultSchema.createIndices) {
      legacy.raw.execute(index);
    }
    legacy.raw.execute('DROP TABLE IF EXISTS categories;');
    legacy.raw.execute('PRAGMA user_version = 1;');
    legacy.close();

    final migrated = VaultDatabase.open(dbPath, key);
    addTearDown(migrated.close);

    final tables = migrated.raw.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='categories';",
    );
    final version = migrated.raw.select('PRAGMA user_version;').first['user_version'] as int;
    expect(tables.length, 1);
    expect(version, VaultSchema.version);
  });

  test('sets user_version to the current schema version on creation', () {
    final db = VaultDatabase.open(dbPath, key);
    addTearDown(db.close);

    final version = db.raw.select('PRAGMA user_version;').first['user_version'] as int;

    expect(version, VaultSchema.version);
  });

  test('data written under one key is readable after closing and reopening with it', () {
    final first = VaultDatabase.open(dbPath, key);
    first.raw.execute(
      'INSERT INTO vault_items (type, title, created_at, updated_at) VALUES (?, ?, ?, ?);',
      ['password', 'GitHub', 1000, 1000],
    );
    first.close();

    final reopened = VaultDatabase.open(dbPath, key);
    addTearDown(reopened.close);
    final rows = reopened.raw.select('SELECT title FROM vault_items;');

    expect(rows.single['title'], 'GitHub');
  });

  test('opening an existing database with the wrong key throws InvalidDatabaseKeyException', () {
    VaultDatabase.open(dbPath, key).close();

    expect(
      () => VaultDatabase.open(dbPath, otherKey),
      throwsA(isA<InvalidDatabaseKeyException>()),
    );
  });

  test('the file on disk is not a plaintext SQLite database', () async {
    VaultDatabase.open(dbPath, key).close();

    final header = await File(dbPath).openRead(0, 16).first;
    final headerText = String.fromCharCodes(header.take(15));

    // Todo archivo SQLite sin cifrar empieza por estos 15 bytes ASCII
    // exactos (seguidos de un NUL). La primera página de un archivo
    // cifrado con SQLCipher está ella misma cifrada, así que no debe
    // empezar por ellos — esto es lo que demuestra que el cifrado está
    // ocurriendo de verdad, en vez de solo confiar en que la librería se
    // configuró bien.
    const plainSqliteMagic = 'SQLite format 3';
    expect(headerText, isNot(plainSqliteMagic));
  });

  group('rekey', () {
    test('the database is only readable with the new key afterwards', () {
      final db = VaultDatabase.open(dbPath, key);
      db.raw.execute(
        'INSERT INTO vault_items (type, title, created_at, updated_at) VALUES (?, ?, ?, ?);',
        ['password', 'GitHub', 1000, 1000],
      );

      db.rekey(otherKey);
      db.close();

      expect(
        () => VaultDatabase.open(dbPath, key),
        throwsA(isA<InvalidDatabaseKeyException>()),
      );
      final reopened = VaultDatabase.open(dbPath, otherKey);
      addTearDown(reopened.close);
      expect(reopened.raw.select('SELECT title FROM vault_items;').single['title'], 'GitHub');
    });

    test('data survives the rekey without needing to be rewritten', () {
      final db = VaultDatabase.open(dbPath, key);
      db.raw.execute(
        'INSERT INTO vault_items (type, title, created_at, updated_at) VALUES (?, ?, ?, ?);',
        ['password', 'Netflix', 2000, 2000],
      );

      db.rekey(otherKey);

      // Sigue usable en la misma conexión, ya rekeyed, sin reabrir.
      final rows = db.raw.select('SELECT title FROM vault_items;');
      expect(rows.single['title'], 'Netflix');
      db.close();
    });
  });
}
