import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/database/vault_session.dart';
import 'package:nexuskeys/features/vault/data/datasources/vault_local_data_source.dart';
import 'package:nexuskeys/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item_type.dart';

void main() {
  late Directory tempDir;
  late VaultSession session;
  late VaultRepositoryImpl repository;

  final key = Uint8List.fromList(List.generate(32, (i) => i));

  VaultItem draft({String title = 'GitHub'}) {
    final now = DateTime.now();
    return VaultItem(type: VaultItemType.password, title: title, createdAt: now, updatedAt: now);
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nexuskeys_vault_repo_test_');
    session = VaultSession(overrideDirectory: tempDir);
    await session.unlock(key);
    repository = VaultRepositoryImpl(dataSource: VaultLocalDataSource(vaultSession: session));
  });

  tearDown(() async {
    repository.dispose();
    session.lock();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('currentItems starts empty on a fresh vault', () {
    expect(repository.currentItems, isEmpty);
  });

  test('create adds the item, assigns an id, and currentItems reflects it exactly', () async {
    final created = await repository.create(draft());

    expect(created.id, isNotNull);
    expect(repository.currentItems, [created]);
  });

  test('itemsStream emits a fresh list after every create', () async {
    final emissions = <int>[];
    final sub = repository.itemsStream.listen((items) => emissions.add(items.length));
    addTearDown(sub.cancel);

    await repository.create(draft(title: 'One'));
    await repository.create(draft(title: 'Two'));
    await Future<void>.delayed(Duration.zero);

    expect(emissions, [1, 2]);
  });

  test('update persists changes and bumps updatedAt', () async {
    final created = await repository.create(draft());
    final before = created.updatedAt;

    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repository.update(created.copyWith(title: 'GitHub Pro'));

    final updated = repository.currentItems.single;
    expect(updated.title, 'GitHub Pro');
    expect(updated.updatedAt.isAfter(before), isTrue);
  });

  test('update without an id throws', () async {
    expect(() => repository.update(draft()), throwsArgumentError);
  });

  test('setFavorite flips the flag', () async {
    final created = await repository.create(draft());

    await repository.setFavorite(created.id!, true);

    expect(repository.currentItems.single.isFavorite, isTrue);
  });

  test('moveToTrash removes the item from currentItems and adds it to currentTrash', () async {
    final created = await repository.create(draft());

    await repository.moveToTrash(created.id!);

    expect(repository.currentItems, isEmpty);
    final trashed = repository.currentTrash.single;
    expect(trashed.id, created.id);
    expect(trashed.isDeleted, isTrue);
  });

  test('restoreFromTrash moves the item back to currentItems', () async {
    final created = await repository.create(draft());
    await repository.moveToTrash(created.id!);

    await repository.restoreFromTrash(created.id!);

    expect(repository.currentTrash, isEmpty);
    expect(repository.currentItems.single.id, created.id);
  });

  test('deletePermanently removes the item from both lists', () async {
    final created = await repository.create(draft());
    await repository.moveToTrash(created.id!);

    await repository.deletePermanently(created.id!);

    expect(repository.currentItems, isEmpty);
    expect(repository.currentTrash, isEmpty);
  });

  test('reload re-queries against the current database connection', () async {
    await repository.create(draft());
    expect(repository.currentItems, hasLength(1));

    await repository.reload();

    expect(repository.currentItems, hasLength(1));
  });
}
