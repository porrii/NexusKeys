import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/database/vault_session.dart';
import 'package:nexuskeys/features/vault/data/datasources/category_local_data_source.dart';
import 'package:nexuskeys/features/vault/data/repositories/category_repository_impl.dart';

void main() {
  late Directory tempDir;
  late VaultSession session;
  late CategoryRepositoryImpl repository;

  final key = Uint8List.fromList(List.generate(32, (i) => i));

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nexuskeys_category_repo_test_');
    session = VaultSession(overrideDirectory: tempDir);
    await session.unlock(key);
    repository = CategoryRepositoryImpl(dataSource: CategoryLocalDataSource(vaultSession: session));
  });

  tearDown(() async {
    repository.dispose();
    session.lock();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('currentCategories starts empty on a fresh vault', () {
    expect(repository.currentCategories, isEmpty);
  });

  test('create adds the category, assigns an id, and currentCategories reflects it exactly', () async {
    final created = await repository.create('Bancario');

    expect(created.id, isNotNull);
    expect(created.name, 'Bancario');
    expect(repository.currentCategories, [created]);
  });

  test('create rejects a duplicate name', () async {
    await repository.create('Bancario');

    expect(() => repository.create('Bancario'), throwsArgumentError);
    expect(repository.currentCategories, hasLength(1));
  });

  test('categoriesStream emits a fresh list after every create', () async {
    final emissions = <int>[];
    final sub = repository.categoriesStream.listen((categories) => emissions.add(categories.length));
    addTearDown(sub.cancel);

    await repository.create('One');
    await repository.create('Two');
    await Future<void>.delayed(Duration.zero);

    expect(emissions, [1, 2]);
  });

  test('delete removes the category', () async {
    final created = await repository.create('Documentos');

    await repository.delete(created.id!);

    expect(repository.currentCategories, isEmpty);
  });

  test('reload re-queries against the current database connection', () async {
    await repository.create('Identidad');
    expect(repository.currentCategories, hasLength(1));

    await repository.reload();

    expect(repository.currentCategories, hasLength(1));
  });
}
