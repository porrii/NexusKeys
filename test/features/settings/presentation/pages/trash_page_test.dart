import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/di/service_locator.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/settings/presentation/pages/trash_page.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item_type.dart';
import 'package:nexuskeys/features/vault/domain/repositories/vault_repository.dart';

/// Fake mínimo — solo tiene que hacer algo la parte relacionada con la
/// papelera que trash_page.dart llama de verdad.
class FakeVaultRepository implements VaultRepository {
  FakeVaultRepository(this.currentTrash);

  @override
  List<VaultItem> currentTrash;

  @override
  List<VaultItem> currentItems = const [];

  final _trashController = StreamController<List<VaultItem>>.broadcast();
  int? lastRestoredId;
  int? lastDeletedId;

  @override
  Stream<List<VaultItem>> get trashStream => _trashController.stream;

  @override
  Stream<List<VaultItem>> get itemsStream => const Stream.empty();

  @override
  Future<void> restoreFromTrash(int id) async {
    lastRestoredId = id;
    currentTrash = currentTrash.where((i) => i.id != id).toList();
    _trashController.add(currentTrash);
  }

  @override
  Future<void> deletePermanently(int id) async {
    lastDeletedId = id;
    currentTrash = currentTrash.where((i) => i.id != id).toList();
    _trashController.add(currentTrash);
  }

  @override
  Future<VaultItem> create(VaultItem draft) async => draft;

  @override
  Future<void> update(VaultItem item) async {}

  @override
  Future<void> setFavorite(int id, bool isFavorite) async {}

  @override
  Future<void> moveToTrash(int id) async {}

  @override
  Future<void> reload() async {}

  @override
  void dispose() => _trashController.close();
}

void main() {
  VaultItem trashedItem({int id = 1, String title = 'GitHub'}) {
    final now = DateTime.now();
    return VaultItem(
      id: id,
      type: VaultItemType.password,
      title: title,
      isDeleted: true,
      createdAt: now,
      updatedAt: now,
      deletedAt: now,
    );
  }

  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  testWidgets('shows an empty message when the trash is empty', (tester) async {
    await sl.reset();
    sl.registerSingleton<VaultRepository>(FakeVaultRepository(const []));

    await tester.pumpWidget(wrap(const TrashPage()));

    expect(find.text('La papelera está vacía'), findsOneWidget);
  });

  testWidgets('lists every trashed item with its type label', (tester) async {
    await sl.reset();
    sl.registerSingleton<VaultRepository>(FakeVaultRepository([trashedItem()]));

    await tester.pumpWidget(wrap(const TrashPage()));

    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
  });

  testWidgets('tapping restore calls restoreFromTrash with the item id', (tester) async {
    await sl.reset();
    final repository = FakeVaultRepository([trashedItem(id: 7)]);
    sl.registerSingleton<VaultRepository>(repository);

    await tester.pumpWidget(wrap(const TrashPage()));
    await tester.tap(find.byIcon(Icons.restore_outlined));
    await tester.pump();

    expect(repository.lastRestoredId, 7);
  });

  testWidgets('permanent delete asks for confirmation before calling deletePermanently', (tester) async {
    await sl.reset();
    final repository = FakeVaultRepository([trashedItem(id: 9)]);
    sl.registerSingleton<VaultRepository>(repository);

    await tester.pumpWidget(wrap(const TrashPage()));
    await tester.tap(find.byIcon(Icons.delete_forever_outlined));
    await tester.pumpAndSettle();
    expect(repository.lastDeletedId, isNull, reason: 'should wait for confirmation');

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(repository.lastDeletedId, 9);
  });
}
