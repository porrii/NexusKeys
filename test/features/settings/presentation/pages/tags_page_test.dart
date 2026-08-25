import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/di/service_locator.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/settings/presentation/pages/tags_page.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item_type.dart';
import 'package:nexuskeys/features/vault/domain/repositories/vault_repository.dart';

class _FakeVaultRepository implements VaultRepository {
  _FakeVaultRepository(this.currentItems);

  @override
  List<VaultItem> currentItems;

  @override
  List<VaultItem> currentTrash = const [];

  @override
  Stream<List<VaultItem>> get itemsStream => const Stream.empty();

  @override
  Stream<List<VaultItem>> get trashStream => const Stream.empty();

  @override
  Future<VaultItem> create(VaultItem draft) async => draft;

  @override
  Future<void> update(VaultItem item) async {
    currentItems = [
      for (final existing in currentItems) existing.id == item.id ? item : existing,
    ];
  }

  @override
  Future<void> setFavorite(int id, bool isFavorite) async {}

  @override
  Future<void> moveToTrash(int id) async {}

  @override
  Future<void> restoreFromTrash(int id) async {}

  @override
  Future<void> deletePermanently(int id) async {}

  @override
  Future<void> reload() async {}

  @override
  void dispose() {}
}

void main() {
  VaultItem item({int? id, required String title, List<String> tags = const []}) {
    final now = DateTime.now();
    return VaultItem(
      id: id,
      type: VaultItemType.password,
      title: title,
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );
  }

  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  setUp(() async {
    await sl.reset();
  });

  testWidgets('shows an empty message when no item has a tag', (tester) async {
    sl.registerSingleton<VaultRepository>(_FakeVaultRepository([item(title: 'GitHub')]));

    await tester.pumpWidget(wrap(const TagsPage()));

    expect(find.text('Ningún elemento tiene etiquetas todavía'), findsOneWidget);
  });

  testWidgets('lists every distinct tag with how many items carry it', (tester) async {
    sl.registerSingleton<VaultRepository>(
      _FakeVaultRepository([
        item(title: 'GitHub', tags: ['Work', 'Dev']),
        item(title: 'Gmail', tags: ['Personal']),
        item(title: 'GitLab', tags: ['Work']),
      ]),
    );

    await tester.pumpWidget(wrap(const TagsPage()));

    expect(find.text('Work'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Dev'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
  });

  testWidgets('renaming a tag updates every item that carries it', (tester) async {
    final repository = _FakeVaultRepository([
      item(id: 1, title: 'GitHub', tags: ['Work']),
      item(id: 2, title: 'GitLab', tags: ['Work', 'Dev']),
    ]);
    sl.registerSingleton<VaultRepository>(repository);

    await tester.pumpWidget(wrap(const TagsPage()));
    // Tags render alphabetically ('Dev' before 'Work') — the last menu
    // button is the one on the 'Work' row.
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renombrar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Trabajo');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Trabajo'), findsOneWidget);
    expect(find.text('Work'), findsNothing);
    expect(repository.currentItems[0].tags, ['Trabajo']);
    expect(repository.currentItems[1].tags, ['Trabajo', 'Dev']);
  });

  testWidgets('deleting a tag asks for confirmation, then removes it from every item', (tester) async {
    final repository = _FakeVaultRepository([
      item(id: 1, title: 'GitHub', tags: ['Work']),
      item(id: 2, title: 'GitLab', tags: ['Work', 'Dev']),
    ]);
    sl.registerSingleton<VaultRepository>(repository);

    await tester.pumpWidget(wrap(const TagsPage()));
    // Tags render alphabetically ('Dev' before 'Work') — the last menu
    // button is the one on the 'Work' row.
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar esta etiqueta?'), findsOneWidget);

    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsNothing);
    expect(repository.currentItems[0].tags, isEmpty);
    expect(repository.currentItems[1].tags, ['Dev']);
  });
}
