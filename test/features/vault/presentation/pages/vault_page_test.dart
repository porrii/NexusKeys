import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexuskeys/core/database/vault_session.dart';
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
import 'package:nexuskeys/features/vault/domain/entities/vault_item.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item_type.dart';
import 'package:nexuskeys/features/vault/domain/repositories/vault_repository.dart';
import 'package:nexuskeys/features/vault/presentation/pages/vault_page.dart';

/// Bare stubs — VaultPage's own tests never open the biometric-enabling
/// flow inside SettingsPage, they just need SettingsPage to build at all
/// (it reads these via the service locator in its State's field
/// initializers). Real behaviour is covered by settings_page_test.dart.
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

  @override
  Future<AuthResult> deleteVault({required String password}) =>
      throw UnimplementedError();
}

/// Hand-written fake instead of a mocking framework, mirroring
/// FakeAuthRepository in auth_gate_page_test.dart. Its own correctness
/// (real SQLCipher-backed behaviour) is covered separately by
/// vault_repository_impl_test.dart; this fake only needs to be controllable
/// enough to exercise VaultPage's UI logic.
class FakeVaultRepository implements VaultRepository {
  @override
  List<VaultItem> currentItems = [];

  @override
  List<VaultItem> currentTrash = [];

  final _itemsController = StreamController<List<VaultItem>>.broadcast();

  int _nextId = 1;

  void seed(List<VaultItem> seedItems) {
    currentItems = seedItems;
  }

  @override
  Stream<List<VaultItem>> get itemsStream => _itemsController.stream;

  @override
  Stream<List<VaultItem>> get trashStream => const Stream.empty();

  @override
  Future<VaultItem> create(VaultItem draft) async {
    final created = draft.copyWith(id: _nextId++);
    currentItems = [...currentItems, created];
    _itemsController.add(currentItems);
    return created;
  }

  @override
  Future<void> update(VaultItem item) async {
    currentItems = [
      for (final existing in currentItems) existing.id == item.id ? item : existing,
    ];
    _itemsController.add(currentItems);
  }

  @override
  Future<void> setFavorite(int id, bool isFavorite) async {}

  @override
  Future<void> moveToTrash(int id) async {
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
  void dispose() {
    _itemsController.close();
  }
}

void main() {
  late FakeVaultRepository fakeRepository;
  late Directory tempDir;

  setUp(() async {
    fakeRepository = FakeVaultRepository();
    tempDir = await Directory.systemTemp.createTemp('nexuskeys_vault_page_test_');
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
    sl.registerSingleton<VaultSession>(VaultSession(overrideDirectory: tempDir));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  VaultItem item({
    required String title,
    String? username,
    bool favorite = false,
  }) {
    final now = DateTime.now();
    return VaultItem(
      type: VaultItemType.password,
      title: title,
      username: username,
      isFavorite: favorite,
      createdAt: now,
      updatedAt: now,
    );
  }

  List<VaultItem> sampleItems() => [
        item(title: 'Google', username: 'ivan@gmail.com', favorite: true),
        item(title: 'GitHub', username: 'ivan_dev'),
        item(title: 'YouTube', username: 'ivan@gmail.com'),
        item(title: 'Netflix', username: 'ivan@gmail.com'),
        item(title: 'Tarjeta Banco'),
        item(title: 'Correo Pro', username: 'ivan@protonmail.com'),
      ];

  // ListView.builder only builds items within the viewport, and the default
  // test surface is too short to fit all six sample rows below the app bar,
  // search field and filter chips. Its 400-wide, phone-shaped size also
  // keeps every test in this file below kVaultWideBreakpoint, since they
  // all exercise the mobile Scaffold specifically — the wide layout has
  // its own test file.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('renders every element from img/03_vault.png', (tester) async {
    useTallViewport(tester);
    fakeRepository.seed(sampleItems());

    await tester.pumpWidget(wrap(const VaultPage()));
    await tester.pumpAndSettle();

    expect(find.text('NexusKeys'), findsOneWidget);
    expect(find.text('Buscar en la bóveda'), findsOneWidget);
    expect(find.text('Todas'), findsOneWidget);
    expect(find.text('Favoritos'), findsOneWidget);
    expect(find.text('Recientes'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Tarjeta Banco'), findsOneWidget);
    expect(find.text('Correo Pro'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Bóveda'), findsOneWidget);
    expect(find.text('Generador'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
  });

  testWidgets('shows an empty-vault message when there are no items', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const VaultPage()));
    await tester.pumpAndSettle();

    expect(find.text('Tu bóveda está vacía'), findsOneWidget);
  });

  testWidgets('the Favoritos chip filters the list down to favorite items only', (tester) async {
    useTallViewport(tester);
    fakeRepository.seed(sampleItems());

    await tester.pumpWidget(wrap(const VaultPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favoritos'));
    await tester.pumpAndSettle();

    expect(find.text('Google'), findsOneWidget);
    expect(find.text('GitHub'), findsNothing);
  });

  testWidgets('the FAB opens the create-item form, and saving adds it to the list', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const VaultPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo elemento'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Título'), 'ProtonMail');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo elemento'), findsNothing);
    expect(find.text('ProtonMail'), findsOneWidget);
  });

  testWidgets('tapping an item opens its read-only details (img/04_item_details.png)', (tester) async {
    useTallViewport(tester);
    fakeRepository.seed([item(title: 'GitHub', username: 'ivan_dev')]);

    await tester.pumpWidget(wrap(const VaultPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();

    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
    expect(find.text('ivan_dev'), findsOneWidget);
    // The bottom nav must stay put across every section of the app —
    // viewing an item's details is not an exception.
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('editing from the details screen persists the change through the repository', (tester) async {
    useTallViewport(tester);
    fakeRepository.seed([item(title: 'GitHub', username: 'ivan_dev')]);

    await tester.pumpWidget(wrap(const VaultPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Título'), 'GitHub Enterprise');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('GitHub Enterprise'), findsOneWidget);
    expect(fakeRepository.currentItems.single.title, 'GitHub Enterprise');
  });

  testWidgets('the AppBar lock icon calls onLock', (tester) async {
    useTallViewport(tester);
    var locked = false;
    await tester.pumpWidget(wrap(VaultPage(onLock: () => locked = true)));

    await tester.tap(find.byTooltip('Bloquear bóveda'));
    await tester.pumpAndSettle();

    expect(locked, isTrue);
  });

  testWidgets('tapping Generador opens the generator screen without calling onLock', (tester) async {
    useTallViewport(tester);
    var locked = false;
    await tester.pumpWidget(wrap(VaultPage(onLock: () => locked = true)));

    await tester.tap(find.text('Generador'));
    await tester.pumpAndSettle();

    expect(locked, isFalse);
    expect(find.text('Generar contraseña'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('tapping Ajustes opens the settings screen without calling onLock', (tester) async {
    useTallViewport(tester);
    var locked = false;
    await tester.pumpWidget(wrap(VaultPage(onLock: () => locked = true)));

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();

    expect(locked, isFalse);
    expect(find.text('SEGURIDAD'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('switching tabs and back preserves the search text', (tester) async {
    useTallViewport(tester);
    fakeRepository.seed(sampleItems());

    await tester.pumpWidget(wrap(const VaultPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'git');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('SEGURIDAD'), findsOneWidget);

    await tester.tap(find.text('Bóveda'));
    await tester.pumpAndSettle();

    expect(find.text('git'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('Netflix'), findsNothing);
  });

  testWidgets('tapping the active tab again pops it back to its own root', (tester) async {
    useTallViewport(tester);
    fakeRepository.seed([item(title: 'GitHub', username: 'ivan_dev')]);

    await tester.pumpWidget(wrap(const VaultPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();
    expect(find.text('Editar'), findsOneWidget);

    await tester.tap(find.text('Bóveda'));
    await tester.pumpAndSettle();

    expect(find.text('Editar'), findsNothing);
    expect(find.text('GitHub'), findsOneWidget);
  });

  group('search (img/07_search.png)', () {
    testWidgets('tapping the search field enters search mode', (tester) async {
      useTallViewport(tester);
      fakeRepository.seed(sampleItems());
      await tester.pumpWidget(wrap(const VaultPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Todas'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('typing filters results and shows a result count', (tester) async {
      useTallViewport(tester);
      fakeRepository.seed([
        item(title: 'Google', username: 'ivan@gmail.com', favorite: true),
        item(title: 'Google Workspace', username: 'trabajo@empresa.com'),
        item(title: 'GitHub', username: 'ivan_dev'),
      ]);
      await tester.pumpWidget(wrap(const VaultPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'goo');
      await tester.pumpAndSettle();

      expect(find.text('Resultados (2)'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Google Workspace'), findsOneWidget);
      expect(find.text('GitHub'), findsNothing);
    });

    testWidgets('matches on username too, not just title', (tester) async {
      useTallViewport(tester);
      fakeRepository.seed(sampleItems());
      await tester.pumpWidget(wrap(const VaultPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'protonmail');
      await tester.pumpAndSettle();

      expect(find.text('Resultados (1)'), findsOneWidget);
      expect(find.text('Correo Pro'), findsOneWidget);
    });

    testWidgets('non-favorite results show an outline star, not a chevron', (tester) async {
      useTallViewport(tester);
      fakeRepository.seed([item(title: 'GitHub', username: 'ivan_dev')]);
      await tester.pumpWidget(wrap(const VaultPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'git');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_border), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('Cancelar exits search mode and restores the filter chips', (tester) async {
      useTallViewport(tester);
      fakeRepository.seed(sampleItems());
      await tester.pumpWidget(wrap(const VaultPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'goo');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('Cancelar'), findsNothing);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('an empty query while searching shows every item', (tester) async {
      useTallViewport(tester);
      fakeRepository.seed(sampleItems());
      await tester.pumpWidget(wrap(const VaultPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('Resultados (${sampleItems().length})'), findsOneWidget);
    });
  });
}
