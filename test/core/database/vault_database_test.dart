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

    // Every unencrypted SQLite file starts with these exact 15 ASCII bytes
    // (followed by a NUL). A SQLCipher-encrypted file's first page is
    // itself encrypted, so it must not start with them - this is what
    // proves encryption is actually happening, rather than just trusting
    // that the library was configured correctly.
    const plainSqliteMagic = 'SQLite format 3';
    expect(headerText, isNot(plainSqliteMagic));
  });
}
