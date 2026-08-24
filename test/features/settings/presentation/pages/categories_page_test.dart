import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/di/service_locator.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/settings/presentation/pages/categories_page.dart';
import 'package:nexuskeys/features/vault/domain/entities/category.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item_type.dart';
import 'package:nexuskeys/features/vault/domain/repositories/category_repository.dart';
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

/// Real create/unique-name behaviour, kept in memory instead of SQLCipher —
/// CategoryRepositoryImpl's own DB-backed logic is covered separately by
/// category_repository_impl_test.dart.
class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository(this.currentCategories);

  @override
  List<Category> currentCategories;

  final _controller = StreamController<List<Category>>.broadcast();
  int _nextId = 1;

  @override
  Stream<List<Category>> get categoriesStream => _controller.stream;

  @override
  Future<Category> create(String name) async {
    if (currentCategories.any((c) => c.name == name)) {
      throw ArgumentError('A category named "$name" already exists');
    }
    final category = Category(id: _nextId++, name: name, createdAt: DateTime.now());
    currentCategories = [...currentCategories, category];
    _controller.add(currentCategories);
    return category;
  }

  @override
  Future<void> delete(int id) async {
    currentCategories = currentCategories.where((c) => c.id != id).toList();
    _controller.add(currentCategories);
  }

  @override
  Future<void> reload() async {}

  @override
  void dispose() => _controller.close();
}

void main() {
  VaultItem item({required String title, String? category}) {
    final now = DateTime.now();
    return VaultItem(
      type: VaultItemType.password,
      title: title,
      category: category,
      createdAt: now,
      updatedAt: now,
    );
  }

  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  setUp(() async {
    await sl.reset();
  });

  testWidgets('renders every element from img/11_categories.png', (tester) async {
    sl.registerSingleton<VaultRepository>(
      _FakeVaultRepository([
        item(title: 'GitHub', category: 'Inicio de sesión'),
        item(title: 'Visa', category: 'Tarjetas'),
        item(title: 'Nota', category: 'Tarjetas'),
      ]),
    );
    sl.registerSingleton<CategoryRepository>(
      _FakeCategoryRepository([
        Category(id: 1, name: 'Inicio de sesión', createdAt: DateTime.now()),
        Category(id: 2, name: 'Tarjetas', createdAt: DateTime.now()),
      ]),
    );

    await tester.pumpWidget(wrap(const CategoriesPage()));

    expect(find.text('Categorías'), findsOneWidget);
    expect(find.text('Todas'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // Todas' total count
    expect(find.text('Inicio de sesión'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Tarjetas'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Nueva categoría'), findsOneWidget);
  });

  testWidgets('a category with no items yet shows a 0 count', (tester) async {
    sl.registerSingleton<VaultRepository>(_FakeVaultRepository(const []));
    sl.registerSingleton<CategoryRepository>(
      _FakeCategoryRepository([Category(id: 1, name: 'Bancario', createdAt: DateTime.now())]),
    );

    await tester.pumpWidget(wrap(const CategoriesPage()));

    expect(find.text('Bancario'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2)); // Todas and Bancario both empty
  });

  testWidgets('creating a category adds it to the list', (tester) async {
    sl.registerSingleton<VaultRepository>(_FakeVaultRepository(const []));
    sl.registerSingleton<CategoryRepository>(_FakeCategoryRepository(const []));

    await tester.pumpWidget(wrap(const CategoriesPage()));
    await tester.tap(find.text('Nueva categoría'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Licencias');
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    expect(find.text('Licencias'), findsOneWidget);
    expect(sl<CategoryRepository>().currentCategories.single.name, 'Licencias');
  });

  testWidgets('creating a duplicate category shows an error and does not add a row', (tester) async {
    sl.registerSingleton<VaultRepository>(_FakeVaultRepository(const []));
    sl.registerSingleton<CategoryRepository>(
      _FakeCategoryRepository([Category(id: 1, name: 'Documentos', createdAt: DateTime.now())]),
    );

    await tester.pumpWidget(wrap(const CategoriesPage()));
    await tester.tap(find.text('Nueva categoría'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Documentos');
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    expect(find.text('Ya existe una categoría con ese nombre.'), findsOneWidget);
    expect(find.text('Documentos'), findsOneWidget);
    expect(sl<CategoryRepository>().currentCategories, hasLength(1));
  });

  testWidgets('cancelling the new-category dialog creates nothing', (tester) async {
    sl.registerSingleton<VaultRepository>(_FakeVaultRepository(const []));
    sl.registerSingleton<CategoryRepository>(_FakeCategoryRepository(const []));

    await tester.pumpWidget(wrap(const CategoriesPage()));
    await tester.tap(find.text('Nueva categoría'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Algo');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(sl<CategoryRepository>().currentCategories, isEmpty);
  });
}
