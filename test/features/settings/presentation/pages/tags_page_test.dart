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
  Future<void> update(VaultItem item) async {}

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
  VaultItem item({required String title, List<String> tags = const []}) {
    final now = DateTime.now();
    return VaultItem(type: VaultItemType.password, title: title, tags: tags, createdAt: now, updatedAt: now);
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
}
