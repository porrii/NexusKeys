import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/database/vault_session.dart';
import 'package:nexuskeys/features/vault/data/datasources/vault_local_data_source.dart';

void main() {
  late Directory tempDir;
  late VaultSession session;
  late VaultLocalDataSource dataSource;

  final key = Uint8List.fromList(List.generate(32, (i) => i));

  Map<String, Object?> sampleValues({String title = 'GitHub'}) => {
        'type': 'password',
        'title': title,
        'username': 'ivan_dev',
        'password': 's3cr3t',
        'url': 'https://github.com',
        'notes': null,
        'category': null,
        'tags': '[]',
        'color': null,
        'icon': null,
        'is_favorite': 0,
        'is_deleted': 0,
        'created_at': 1000,
        'updated_at': 1000,
        'deleted_at': null,
      };

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nexuskeys_vault_ds_test_');
    session = VaultSession(overrideDirectory: tempDir);
    await session.unlock(key);
    dataSource = VaultLocalDataSource(vaultSession: session);
  });

  tearDown(() async {
    session.lock();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('selectAll is empty on a fresh database', () {
    expect(dataSource.selectAll(deleted: false), isEmpty);
    expect(dataSource.selectAll(deleted: true), isEmpty);
  });

  test('insert then selectAll returns the row with an assigned id', () {
    final id = dataSource.insert(sampleValues());

    final rows = dataSource.selectAll(deleted: false);
    expect(rows, hasLength(1));
    expect(rows.single['id'], id);
    expect(rows.single['title'], 'GitHub');
    expect(rows.single['username'], 'ivan_dev');
  });

  test('update changes the row in place', () {
    final id = dataSource.insert(sampleValues());

    dataSource.update(id, {...sampleValues(title: 'GitHub Pro'), 'updated_at': 2000});

    final row = dataSource.selectAll(deleted: false).single;
    expect(row['title'], 'GitHub Pro');
    expect(row['updated_at'], 2000);
  });

  test('setFavorite flips is_favorite without touching anything else', () {
    final id = dataSource.insert(sampleValues());

    dataSource.setFavorite(id, true);

    expect(dataSource.selectAll(deleted: false).single['is_favorite'], 1);
  });

  test('softDelete moves a row from the active list to the trash', () {
    final id = dataSource.insert(sampleValues());

    dataSource.softDelete(id, 5000);

    expect(dataSource.selectAll(deleted: false), isEmpty);
    final trashed = dataSource.selectAll(deleted: true).single;
    expect(trashed['id'], id);
    expect(trashed['deleted_at'], 5000);
  });

  test('restore moves a row back from the trash to the active list', () {
    final id = dataSource.insert(sampleValues());
    dataSource.softDelete(id, 5000);

    dataSource.restore(id);

    expect(dataSource.selectAll(deleted: true), isEmpty);
    final restored = dataSource.selectAll(deleted: false).single;
    expect(restored['id'], id);
    expect(restored['deleted_at'], isNull);
  });

  test('hardDelete removes the row entirely', () {
    final id = dataSource.insert(sampleValues());
    dataSource.softDelete(id, 5000);

    dataSource.hardDelete(id);

    expect(dataSource.selectAll(deleted: false), isEmpty);
    expect(dataSource.selectAll(deleted: true), isEmpty);
  });
}
