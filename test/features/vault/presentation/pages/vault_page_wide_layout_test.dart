import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexuskeys/core/di/service_locator.dart';
import 'package:nexuskeys/core/security/crypto_service.dart';
import 'package:nexuskeys/core/security/crypto_service_impl.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/auth/domain/entities/auth_result.dart';
import 'package:nexuskeys/features/auth/domain/repositories/auth_repository.dart';
import 'package:nexuskeys/features/auth/domain/services/biometric_service.dart';
import 'package:nexuskeys/features/auth/domain/services/vault_key_store.dart';
import 'package:nexuskeys/features/generator/domain/services/password_generator_service.dart';
import 'package:nexuskeys/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:nexuskeys/features/settings/domain/repositories/settings_repository.dart';
import 'package:nexuskeys/features/vault/domain/entities/category.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item_type.dart';
import 'package:nexuskeys/features/vault/domain/repositories/category_repository.dart';
import 'package:nexuskeys/features/vault/domain/repositories/vault_repository.dart';
import 'package:nexuskeys/features/vault/presentation/pages/vault_page.dart';

// Same stubs as vault_page_test.dart's mobile suite — see its own doc
// comments for why each exists. Duplicated rather than shared because the
// two files exercise genuinely different Scaffolds (see
// kVaultWideBreakpoint) and keeping them independent avoids one file's
// fixture change silently affecting the other.
class _StubBiometricService implements BiometricService {
  @override
  Future<bool> isDeviceSupported() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

class _StubVaultKeyStore implements VaultKeyStore {
  @override
  Future<bool> get hasStoredKey async => false;

  @override
  Future<void> save(Uint8List vaultKey) async {}

  @override
  Future<Uint8List?> read() async => null;

  @override
  Future<void> clear() async {}
}

class _StubAuthRepository implements AuthRepository {
  @override
  Future<bool> isVaultInitialized() async => true;

  @override
  Future<AuthResult> setupMasterPassword(String password) async => AuthSuccess(Uint8List(32));

  @override
  Future<AuthResult> verifyMasterPassword(String password) async =>
      const AuthFailure(AuthFailureReason.wrongPassword);

  @override
  Future<AuthResult> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      throw UnimplementedError();
}

class _StubCategoryRepository implements CategoryRepository {
  @override
  List<Category> currentCategories = const [];

  @override
  Stream<List<Category>> get categoriesStream => const Stream.empty();

  @override
  Future<Category> create(String name) async => Category(name: name, createdAt: DateTime.now());

  @override
  Future<void> delete(int id) async {}

  @override
  Future<void> reload() async {}

  @override
  void dispose() {}
}

class _FakeVaultRepository implements VaultRepository {
  @override
  List<VaultItem> currentItems = [];

  @override
  List<VaultItem> currentTrash = [];

  final _itemsController = StreamController<List<VaultItem>>.broadcast();

  void seed(List<VaultItem> seedItems) {
    currentItems = seedItems;
  }

  @override
  Stream<List<VaultItem>> get itemsStream => _itemsController.stream;

  @override
  Stream<List<VaultItem>> get trashStream => const Stream.empty();

  @override
  Future<VaultItem> create(VaultItem draft) async => draft;

  @override
  Future<void> update(VaultItem item) async {}

  int? lastFavoritedId;
  bool? lastFavoriteValue;

  @override
  Future<void> setFavorite(int id, bool isFavorite) async {
    lastFavoritedId = id;
    lastFavoriteValue = isFavorite;
  }

  int? lastTrashedId;

  @override
  Future<void> moveToTrash(int id) async {
    lastTrashedId = id;
    currentItems = currentItems.where((i) => i.id != id).toList();
    _itemsController.add(currentItems);
  }

  @override
  Future<void> restoreFromTrash(int id) async {}

  @override
  Future<void> deletePermanently(int id) async {}

  @override
  Future<void> reload() async {}

  @override
  void dispose() => _itemsController.close();
}

void main() {
  late _FakeVaultRepository fakeRepository;

  setUp(() async {
    fakeRepository = _FakeVaultRepository();
    await sl.reset();
    sl.registerSingleton<VaultRepository>(fakeRepository);
    sl.registerLazySingleton<CryptoService>(CryptoServiceImpl.new);
    sl.registerLazySingleton(() => PasswordGeneratorService(cryptoService: sl()));
    SharedPreferences.setMockInitialValues({});
    sl.registerSingleton<SettingsRepository>(
      SettingsRepositoryImpl(preferences: await SharedPreferences.getInstance()),
    );
    sl.registerSingleton<BiometricService>(_StubBiometricService());
    sl.registerSingleton<VaultKeyStore>(_StubVaultKeyStore());
    sl.registerSingleton<AuthRepository>(_StubAuthRepository());
    sl.registerSingleton<CategoryRepository>(_StubCategoryRepository());
  });

  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  VaultItem item({int? id, required String title, String? username, bool favorite = false}) {
    final now = DateTime.now();
    return VaultItem(
      id: id,
      type: VaultItemType.password,
      title: title,
      username: username,
      isFavorite: favorite,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Above kVaultWideBreakpoint (700) — this is what actually selects
  // VaultPage's wide Scaffold (sidebar + list + inline detail) instead of
  // its mobile one.
  void useWideViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('renders the sidebar, list and an empty detail placeholder', (tester) async {
    useWideViewport(tester);
    fakeRepository.seed([item(id: 1, title: 'GitHub', username: 'ivan_dev')]);

    await tester.pumpWidget(wrap(const VaultPage()));
    await tester.pumpAndSettle();

    expect(find.text('NexusKeys'), findsOneWidget);
    expect(find.text('Bóveda'), findsOneWidget);
    expect(find.text('Favoritos'), findsOneWidget);
    expect(find.text('Recientes'), findsOneWidget);
    expect(find.text('Categorías'), findsOneWidget);
    expect(find.text('Etiqueta'), findsOneWidget);
    expect(find.text('Papelera'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('Selecciona un elemento'), findsOneWidget);
  });

  testWidgets('tapping an item shows its details inline, without pushing a route', (tester) async {
    useWideViewport(tester);
    fakeRepository.seed([item(id: 1, title: 'GitHub', username: 'ivan_dev')]);

    await tester.pumpWidget(wrap(const VaultPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();

    expect(find.text('Selecciona un elemento'), findsNothing);
    // Once in the list row's subtitle, once in the detail pane's Usuario
    // field — both stay on screen at the same time on wide layouts.
    expect(find.text('ivan_dev'), findsNWidgets(2));
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
    // Sidebar must still be visible — a pushed route would have covered it.
    expect(find.text('NexusKeys'), findsOneWidget);
  });

  testWidgets('the Favoritos sidebar entry filters the list to favorite items', (tester) async {
    useWideViewport(tester);
    fakeRepository.seed([
      item(id: 1, title: 'Google', favorite: true),
      item(id: 2, title: 'GitHub'),
    ]);

    await tester.pumpWidget(wrap(const VaultPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favoritos'));
    await tester.pumpAndSettle();

    expect(find.text('Google'), findsOneWidget);
    expect(find.text('GitHub'), findsNothing);
  });

  testWidgets('the Categorías sidebar entry opens CategoriesPage', (tester) async {
    useWideViewport(tester);

    await tester.pumpWidget(wrap(const VaultPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categorías'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva categoría'), findsOneWidget);
  });

  testWidgets('the Papelera sidebar entry opens TrashPage', (tester) async {
    useWideViewport(tester);

    await tester.pumpWidget(wrap(const VaultPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Papelera'));
    await tester.pumpAndSettle();

    expect(find.text('La papelera está vacía'), findsOneWidget);
  });

  testWidgets('the sidebar lock control calls onLock', (tester) async {
    useWideViewport(tester);
    var locked = false;

    await tester.pumpWidget(wrap(VaultPage(onLock: () => locked = true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bóveda bloqueada'));
    await tester.pumpAndSettle();

    expect(locked, isTrue);
  });

  testWidgets('deleting the selected item clears the detail pane', (tester) async {
    useWideViewport(tester);
    fakeRepository.seed([item(id: 1, title: 'GitHub', username: 'ivan_dev')]);

    await tester.pumpWidget(wrap(const VaultPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(fakeRepository.lastTrashedId, 1);
    expect(find.text('Selecciona un elemento'), findsOneWidget);
  });
}
