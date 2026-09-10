import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/database/vault_session.dart';
import 'package:nexuskeys/core/di/service_locator.dart';
import 'package:nexuskeys/core/security/crypto_service.dart';
import 'package:nexuskeys/core/security/crypto_service_impl.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:nexuskeys/features/auth/domain/entities/auth_result.dart';
import 'package:nexuskeys/features/auth/domain/repositories/auth_repository.dart';
import 'package:nexuskeys/features/auth/domain/services/biometric_service.dart';
import 'package:nexuskeys/features/auth/domain/services/vault_key_store.dart';
import 'package:nexuskeys/features/backup/domain/services/backup_service.dart';
import 'package:nexuskeys/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:nexuskeys/features/settings/domain/repositories/settings_repository.dart';
import 'package:nexuskeys/features/settings/presentation/pages/settings_page.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item.dart';
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

  @override
  bool get hasWarmedUpCipher => false;
}

/// verifyMasterPassword and deleteVault are both exercised from
/// SettingsPage (biometric enable, and "Eliminar bóveda permanentemente"
/// both confirm the master password the same way) — the rest belong to
/// flows this file doesn't touch.
class _FakeAuthRepository implements AuthRepository {
  String? correctPassword = 'master-password';
  bool deleteVaultCalled = false;

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

  @override
  Future<AuthResult> deleteVault({required String password}) async {
    final result = await verifyMasterPassword(password);
    if (result is AuthSuccess) deleteVaultCalled = true;
    return result;
  }
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

void main() {
  late _FakeBiometricService fakeBiometricService;
  late _FakeVaultKeyStore fakeVaultKeyStore;
  late _FakeAuthRepository fakeAuthRepository;
  late Directory tempDir;

  setUp(() async {
    await sl.reset();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('nexuskeys_settings_test_');
    fakeBiometricService = _FakeBiometricService();
    fakeVaultKeyStore = _FakeVaultKeyStore();
    fakeAuthRepository = _FakeAuthRepository();
    sl.registerSingleton<SettingsRepository>(
      SettingsRepositoryImpl(preferences: await SharedPreferences.getInstance()),
    );
    sl.registerSingleton<VaultRepository>(_EmptyVaultRepository());
    sl.registerSingleton<BiometricService>(fakeBiometricService);
    sl.registerSingleton<VaultKeyStore>(fakeVaultKeyStore);
    sl.registerSingleton<AuthRepository>(fakeAuthRepository);
    sl.registerSingleton<VaultSession>(VaultSession(overrideDirectory: tempDir));
    sl.registerLazySingleton<CryptoService>(CryptoServiceImpl.new);
    sl.registerLazySingleton(() => AuthLocalDataSource(overrideDirectory: tempDir));
    sl.registerLazySingleton(
      () => BackupService(cryptoService: sl(), authLocalDataSource: sl(), vaultSession: sl()),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  // The full row list doesn't fit the default test surface.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('renders every row from img/08_settings.png, plus the added sections', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    expect(find.text('SEGURIDAD'), findsOneWidget);
    expect(find.text('Bloqueo automático'), findsOneWidget);
    expect(find.text('5 minutos'), findsOneWidget);
    expect(find.text('Cambiar contraseña maestra'), findsOneWidget);
    if (Platform.isWindows) {
      expect(find.text('Autenticación biométrica'), findsNothing);
    } else {
      expect(find.text('Autenticación biométrica'), findsOneWidget);
      expect(find.text('Desactivada'), findsOneWidget);
    }
    expect(find.text('Bloquear al cerrar'), findsOneWidget);
    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Oscuro'), findsOneWidget);
    expect(find.text('Idioma'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);
    expect(find.text('Etiquetas'), findsOneWidget);
    expect(find.text('Papelera'), findsOneWidget);
    expect(find.text('DATOS'), findsOneWidget);
    expect(find.text('Importar / Exportar'), findsOneWidget);
    expect(find.text('Eliminar bóveda permanentemente'), findsOneWidget);
    expect(find.text('ACERCA DE'), findsOneWidget);
    expect(find.text('Licencias'), findsOneWidget);
    expect(find.text('NexusKeys'), findsOneWidget);
    expect(find.text('Creado por Iván Bezanilla López'), findsOneWidget);
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

  // These four exercise the "Autenticación biométrica" tile, which no
  // longer renders at all when running on Windows (see the new hidden-tile
  // test below) — skipped here rather than made conditional, since there
  // would be nothing left to tap.
  testWidgets(
    'Autenticación biométrica warns when the device has no biometric support',
    (tester) async {
      fakeBiometricService.supported = false;
      useTallViewport(tester);
      await tester.pumpWidget(wrap(const SettingsPage()));

      await tester.tap(find.text('Autenticación biométrica'));
      await tester.pumpAndSettle();

      expect(find.text('Este dispositivo no admite autenticación biométrica.'), findsOneWidget);
      expect(sl<SettingsRepository>().current.biometricEnabled, isFalse);
    },
    skip: Platform.isWindows,
  );

  testWidgets(
    'enabling biometric unlock asks for the master password, then saves the key',
    (tester) async {
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
    },
    skip: Platform.isWindows,
  );

  testWidgets(
    'a wrong password aborts enabling biometric unlock',
    (tester) async {
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
    },
    skip: Platform.isWindows,
  );

  testWidgets(
    'disabling biometric unlock clears the stored key',
    (tester) async {
      await sl<SettingsRepository>().setBiometricEnabled(true);
      fakeVaultKeyStore.stored = Uint8List(32);
      useTallViewport(tester);
      await tester.pumpWidget(wrap(const SettingsPage()));

      await tester.tap(find.text('Autenticación biométrica'));
      await tester.pumpAndSettle();

      expect(sl<SettingsRepository>().current.biometricEnabled, isFalse);
      expect(fakeVaultKeyStore.stored, isNull);
      expect(find.text('Desactivada'), findsOneWidget);
    },
    skip: Platform.isWindows,
  );

  testWidgets('Autenticación biométrica does not appear on Windows', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    expect(find.text('Autenticación biométrica'), findsNothing);
  }, skip: !Platform.isWindows);

  testWidgets('Etiquetas opens the tags screen', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('Etiquetas'));
    await tester.pumpAndSettle();

    expect(find.text('Ningún elemento tiene etiquetas todavía'), findsOneWidget);
  });

  testWidgets('Importar / Exportar opens the import/export screen', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('Importar / Exportar'));
    await tester.pumpAndSettle();

    expect(find.text('EXPORTAR BÓVEDA'), findsOneWidget);
    expect(find.text('IMPORTAR BÓVEDA'), findsOneWidget);
  });

  testWidgets('deleting the vault asks for confirmation, then the master password', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('Eliminar bóveda permanentemente'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar la bóveda permanentemente?'), findsOneWidget);

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Confirma tu contraseña maestra para eliminar la bóveda'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'master-password');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(fakeAuthRepository.deleteVaultCalled, isTrue);
  });

  testWidgets('cancelling the delete confirmation deletes nothing', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('Eliminar bóveda permanentemente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(fakeAuthRepository.deleteVaultCalled, isFalse);
  });

  testWidgets('a wrong password aborts deleting the vault', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('Eliminar bóveda permanentemente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'not-the-password');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Contraseña incorrecta.'), findsOneWidget);
    expect(fakeAuthRepository.deleteVaultCalled, isFalse);
  });

  testWidgets('Licencias opens the built-in Flutter license page', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('Licencias'));
    await tester.pumpAndSettle();

    expect(find.text('NexusKeys'), findsWidgets);
  });

  testWidgets('embedded hides Etiquetas and Papelera, already direct sidebar destinations', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const Scaffold(body: SettingsPage(embedded: true))));

    expect(find.text('Etiquetas'), findsNothing);
    expect(find.text('Papelera'), findsNothing);
  });

  testWidgets('embedded: opening a sub-page swaps it in place instead of pushing a route', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const Scaffold(body: SettingsPage(embedded: true))));

    expect(find.text('Ajustes'), findsOneWidget);
    await tester.tap(find.text('Tema'));
    await tester.pumpAndSettle();

    // Swapped in place, not pushed - the settings list (and its "Ajustes"
    // header) is gone, replaced by the sub-page's own embedded header.
    expect(find.text('Ajustes'), findsNothing);
    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('OLED'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Tema'), findsOneWidget);
  });

  testWidgets('embedded: Bloqueo automático reflects a change back after returning', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const Scaffold(body: SettingsPage(embedded: true))));

    await tester.tap(find.text('Bloqueo automático'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nunca'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Nunca'), findsOneWidget);
  });
}
