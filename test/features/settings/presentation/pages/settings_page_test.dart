import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/di/service_locator.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/auth/domain/entities/auth_result.dart';
import 'package:nexuskeys/features/auth/domain/repositories/auth_repository.dart';
import 'package:nexuskeys/features/auth/domain/services/biometric_service.dart';
import 'package:nexuskeys/features/auth/domain/services/vault_key_store.dart';
import 'package:nexuskeys/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:nexuskeys/features/settings/domain/repositories/settings_repository.dart';
import 'package:nexuskeys/features/settings/presentation/pages/settings_page.dart';
import 'package:nexuskeys/features/vault/domain/entities/category.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item.dart';
import 'package:nexuskeys/features/vault/domain/repositories/category_repository.dart';
import 'package:nexuskeys/features/vault/domain/repositories/vault_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBiometricService implements BiometricService {
  bool supported = true;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> authenticate({required String reason}) async => true;
}

class _FakeVaultKeyStore implements VaultKeyStore {
  Uint8List? stored;
  bool throwOnSave = false;

  @override
  Future<bool> get hasStoredKey async => stored != null;

  @override
  Future<void> save(Uint8List vaultKey) async {
    if (throwOnSave) throw Exception('save failed');
    stored = vaultKey;
  }

  @override
  Future<Uint8List?> read() async => stored;

  @override
  Future<void> clear() async => stored = null;
}

/// Only verifyMasterPassword is exercised from SettingsPage — the other
/// methods belong to flows this file doesn't touch.
class _FakeAuthRepository implements AuthRepository {
  String? correctPassword = 'master-password';

  @override
  Future<bool> isVaultInitialized() async => true;

  @override
  Future<AuthResult> setupMasterPassword(String password) async => AuthSuccess(Uint8List(32));

  @override
  Future<AuthResult> verifyMasterPassword(String password) async {
    if (password == correctPassword) {
      return AuthSuccess(Uint8List.fromList(List.generate(32, (i) => i)));
    }
    return const AuthFailure(AuthFailureReason.wrongPassword);
  }

  @override
  Future<AuthResult> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      throw UnimplementedError();
}

/// Minimal fake — SettingsPage only needs a VaultRepository registered
/// because navigating to "Papelera" pushes TrashPage, which reads one.
/// None of these tests exercise trash behaviour itself (that's
/// trash_page_test.dart's job), so every method here is a bare stub.
class _EmptyVaultRepository implements VaultRepository {
  @override
  List<VaultItem> currentItems = const [];

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

/// Minimal fake — SettingsPage only needs a CategoryRepository registered
/// because navigating to "Gestionar categorías" pushes CategoriesPage.
/// Category CRUD behaviour itself is covered by categories_page_test.dart.
class _EmptyCategoryRepository implements CategoryRepository {
  @override
  List<Category> currentCategories = const [];

  @override
  Stream<List<Category>> get categoriesStream => const Stream.empty();

  @override
  Future<Category> create(String name) async =>
      Category(name: name, createdAt: DateTime.now());

  @override
  Future<void> delete(int id) async {}

  @override
  Future<void> reload() async {}

  @override
  void dispose() {}
}

void main() {
  late _FakeBiometricService fakeBiometricService;
  late _FakeVaultKeyStore fakeVaultKeyStore;
  late _FakeAuthRepository fakeAuthRepository;

  setUp(() async {
    await sl.reset();
    SharedPreferences.setMockInitialValues({});
    fakeBiometricService = _FakeBiometricService();
    fakeVaultKeyStore = _FakeVaultKeyStore();
    fakeAuthRepository = _FakeAuthRepository();
    sl.registerSingleton<SettingsRepository>(
      SettingsRepositoryImpl(preferences: await SharedPreferences.getInstance()),
    );
    sl.registerSingleton<VaultRepository>(_EmptyVaultRepository());
    sl.registerSingleton<CategoryRepository>(_EmptyCategoryRepository());
    sl.registerSingleton<BiometricService>(fakeBiometricService);
    sl.registerSingleton<VaultKeyStore>(fakeVaultKeyStore);
    sl.registerSingleton<AuthRepository>(fakeAuthRepository);
  });

  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  // The full two-section list doesn't fit the default test surface.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('renders every row from img/08_settings.png', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    expect(find.text('SEGURIDAD'), findsOneWidget);
    expect(find.text('Bloqueo automático'), findsOneWidget);
    expect(find.text('5 minutos'), findsOneWidget);
    expect(find.text('Cambiar contraseña maestra'), findsOneWidget);
    expect(find.text('Autenticación biométrica'), findsOneWidget);
    expect(find.text('Desactivada'), findsOneWidget);
    expect(find.text('Bloquear al cerrar'), findsOneWidget);
    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Oscuro'), findsOneWidget);
    expect(find.text('Idioma'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);
    expect(find.text('Gestionar categorías'), findsOneWidget);
    expect(find.text('Papelera'), findsOneWidget);
  });

  testWidgets('Bloquear al cerrar starts on, per the mockup', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isTrue);
  });

  testWidgets('toggling Bloquear al cerrar persists the change', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(sl<SettingsRepository>().current.lockOnClose, isFalse);
  });

  testWidgets('Tema navigates to the theme picker and reflects a change back', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('Tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OLED'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('OLED'), findsOneWidget);
  });

  testWidgets('Papelera opens the trash screen', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('Papelera'));
    await tester.pumpAndSettle();

    expect(find.text('La papelera está vacía'), findsOneWidget);
  });

  testWidgets('Autenticación biométrica warns when the device has no biometric support', (tester) async {
    fakeBiometricService.supported = false;
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('Autenticación biométrica'));
    await tester.pumpAndSettle();

    expect(find.text('Este dispositivo no admite autenticación biométrica.'), findsOneWidget);
    expect(sl<SettingsRepository>().current.biometricEnabled, isFalse);
  });

  testWidgets('enabling biometric unlock asks for the master password, then saves the key', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('Autenticación biométrica'));
    await tester.pumpAndSettle();

    expect(find.text('Confirma tu contraseña maestra'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'master-password');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(sl<SettingsRepository>().current.biometricEnabled, isTrue);
    expect(fakeVaultKeyStore.stored, isNotNull);
    expect(find.text('Activada'), findsOneWidget);
  });

  testWidgets('a wrong password aborts enabling biometric unlock', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('Autenticación biométrica'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'not-the-password');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Contraseña incorrecta.'), findsOneWidget);
    expect(sl<SettingsRepository>().current.biometricEnabled, isFalse);
    expect(fakeVaultKeyStore.stored, isNull);
  });

  testWidgets('disabling biometric unlock clears the stored key', (tester) async {
    await sl<SettingsRepository>().setBiometricEnabled(true);
    fakeVaultKeyStore.stored = Uint8List(32);
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('Autenticación biométrica'));
    await tester.pumpAndSettle();

    expect(sl<SettingsRepository>().current.biometricEnabled, isFalse);
    expect(fakeVaultKeyStore.stored, isNull);
    expect(find.text('Desactivada'), findsOneWidget);
  });

  testWidgets('Gestionar categorías opens the categories screen', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('Gestionar categorías'));
    await tester.pumpAndSettle();

    expect(find.text('Todas'), findsOneWidget);
    expect(find.text('Nueva categoría'), findsOneWidget);
  });
}
