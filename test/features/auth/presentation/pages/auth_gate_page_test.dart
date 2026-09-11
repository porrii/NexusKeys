import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/database/vault_session.dart';
import 'package:nexuskeys/core/di/service_locator.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/auth/domain/entities/auth_result.dart';
import 'package:nexuskeys/features/auth/domain/repositories/auth_repository.dart';
import 'package:nexuskeys/features/auth/domain/services/biometric_service.dart';
import 'package:nexuskeys/features/auth/domain/services/vault_key_store.dart';
import 'package:nexuskeys/features/auth/presentation/pages/auth_gate_page.dart';
import 'package:nexuskeys/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:nexuskeys/features/settings/domain/repositories/settings_repository.dart';
import 'package:nexuskeys/features/vault/di/vault_dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AuthGatePage comprueba esto para decidir si ofrecer el botón de
/// desbloqueo biométrico; todos los tests de este archivo dejan la
/// biometría fuera de juego (ese flujo lo cubren
/// biometric_prompt_page_test.dart y settings_page_test.dart) informando
/// del dispositivo como no compatible.
class _FakeBiometricService implements BiometricService {
  @override
  Future<bool> isDeviceSupported() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

class _FakeVaultKeyStore implements VaultKeyStore {
  @override
  Future<bool> get hasStoredKey async => false;

  @override
  Future<void> save(Uint8List vaultKey) async {}

  @override
  Future<Uint8List?> read() async => null;

  @override
  Future<void> clear() async {}

  @override
  bool get hasWarmedUpCipher => false;
}

/// Fake escrito a mano en vez de un framework de mocking — AuthRepository
/// solo tiene cuatro métodos y así el test no arrastra dependencias. Su
/// propia corrección la cubre aparte auth_repository_impl_test.dart; este
/// fake solo necesita ser lo bastante controlable para ejercitar la
/// lógica de navegación y de mapeo de errores de AuthGatePage.
class FakeAuthRepository implements AuthRepository {
  bool vaultInitialized = false;
  String? configuredPassword;
  AuthFailureReason? nextFailureReason;

  /// Simula el fallo real que motivó este archivo: una excepción
  /// inesperada durante la derivación de la clave (rastreado hasta un
  /// cuelgue real de Argon2id en Windows), en vez de un [AuthFailure]
  /// normal y corriente.
  bool throwOnVerify = false;
  bool throwOnSetup = false;

  @override
  Future<bool> isVaultInitialized() async => vaultInitialized;

  @override
  Future<AuthResult> setupMasterPassword(String password) async {
    if (throwOnSetup) throw StateError('fallo simulado de setupMasterPassword');
    configuredPassword = password;
    vaultInitialized = true;
    return AuthSuccess(Uint8List(32));
  }

  @override
  Future<AuthResult> verifyMasterPassword(String password) async {
    if (throwOnVerify) throw StateError('fallo simulado de verifyMasterPassword');
    if (nextFailureReason case final reason?) return AuthFailure(reason);
    if (!vaultInitialized) return const AuthFailure(AuthFailureReason.vaultNotInitialized);
    if (password != configuredPassword) return const AuthFailure(AuthFailureReason.wrongPassword);
    return AuthSuccess(Uint8List(32));
  }

  @override
  Future<AuthResult> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final verified = await verifyMasterPassword(currentPassword);
    if (verified is! AuthSuccess) return verified;
    return setupMasterPassword(newPassword);
  }

  @override
  Future<AuthResult> deleteVault({required String password}) async {
    final verified = await verifyMasterPassword(password);
    if (verified is! AuthSuccess) return verified;
    vaultInitialized = false;
    configuredPassword = null;
    return verified;
  }
}

void main() {
  late FakeAuthRepository fakeRepository;
  late Directory tempDir;

  setUp(() async {
    fakeRepository = FakeAuthRepository();
    tempDir = await Directory.systemTemp.createTemp('nexuskeys_gate_test_');
    await sl.reset();
    SharedPreferences.setMockInitialValues({});
    sl.registerSingleton<AuthRepository>(fakeRepository);
    sl.registerSingleton<VaultSession>(VaultSession(overrideDirectory: tempDir));
    sl.registerSingleton<BiometricService>(_FakeBiometricService());
    sl.registerSingleton<VaultKeyStore>(_FakeVaultKeyStore());
    sl.registerSingleton<SettingsRepository>(
      SettingsRepositoryImpl(preferences: await SharedPreferences.getInstance()),
    );
    // VaultPage (que se muestra tras un desbloqueo correcto) y el propio
    // reload() post-desbloqueo de AuthGatePage necesitan un VaultRepository
    // real — registrado igual que hace el setupServiceLocator() de
    // producción.
    configureVaultDependencies(sl);
  });

  tearDown(() async {
    // El archivo de base de datos de la bóveda está mapeado en memoria por
    // la conexión SQLCipher aún abierta; en Windows el directorio temporal
    // no se puede borrar hasta que se libere ese handle.
    sl<VaultSession>().lock();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget wrap() => MaterialApp(theme: AppTheme.dark, home: const AuthGatePage());

  testWidgets('shows the welcome screen when no vault exists yet', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Crear nueva bóveda'), findsOneWidget);
  });

  testWidgets('shows the lock screen when a vault already exists', (tester) async {
    fakeRepository.vaultInitialized = true;
    fakeRepository.configuredPassword = 'existing-password';

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Desbloquear bóveda'), findsOneWidget);
  });

  testWidgets('creating a vault navigates through to the vault screen', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear nueva bóveda'));
    await tester.pumpAndSettle();
    expect(find.text('Crear contraseña maestra'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'a-strong-password');
    await tester.enterText(find.byType(TextField).last, 'a-strong-password');
    await tester.tap(find.text('Crear bóveda'));
    await tester.pumpAndSettle();

    expect(find.text('Buscar en la bóveda'), findsOneWidget);
    expect(fakeRepository.configuredPassword, 'a-strong-password');
  });

  testWidgets('a wrong password shows an inline error and stays on the lock screen', (tester) async {
    fakeRepository.vaultInitialized = true;
    fakeRepository.configuredPassword = 'the-real-password';

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'wrong-guess');
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();

    expect(find.text('Contraseña incorrecta'), findsOneWidget);
    expect(find.text('Desbloquear bóveda'), findsOneWidget);
  });

  testWidgets(
    'an unexpected exception while verifying recovers with an error instead of spinning forever',
    (tester) async {
      // Reproduce el bug real: un fallo de verifyMasterPassword que lanza
      // en vez de devolver AuthFailure (p. ej. el cuelgue de Argon2id
      // rastreado en Windows) no debe dejar el botón "Desbloquear"
      // mostrando el spinner para siempre — tiene que recuperarse con un
      // error visible y dejar reintentar.
      fakeRepository.vaultInitialized = true;
      fakeRepository.configuredPassword = 'the-real-password';
      fakeRepository.throwOnVerify = true;

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'the-real-password');
      await tester.tap(find.text('Desbloquear'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo desbloquear la bóveda. Inténtalo de nuevo.'), findsOneWidget);
      // El botón vuelve a ser pulsable (isUnlocking:false) en vez de
      // quedarse deshabilitado con el spinner.
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);

      // Y un reintento normal, sin el fallo, funciona.
      fakeRepository.throwOnVerify = false;
      await tester.tap(find.text('Desbloquear'));
      await tester.pumpAndSettle();

      expect(find.text('Buscar en la bóveda'), findsOneWidget);
    },
  );

  testWidgets('an unexpected exception while creating a vault shows a SnackBar, not a stuck screen',
      (tester) async {
    fakeRepository.throwOnSetup = true;

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear nueva bóveda'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'a-strong-password');
    await tester.enterText(find.byType(TextField).last, 'a-strong-password');
    await tester.tap(find.text('Crear bóveda'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo crear la bóveda. Inténtalo de nuevo.'), findsOneWidget);
    // Sigue en el formulario de creación, no a medio camino de ningún sitio.
    expect(find.text('Crear contraseña maestra'), findsOneWidget);
  });

  testWidgets('the correct password unlocks into the vault screen', (tester) async {
    fakeRepository.vaultInitialized = true;
    fakeRepository.configuredPassword = 'the-real-password';

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'the-real-password');
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();

    expect(find.text('Buscar en la bóveda'), findsOneWidget);
  });

  testWidgets('locking from the vault screen AppBar returns to the lock screen', (tester) async {
    // Por debajo de kVaultWideBreakpoint — la superficie de test por
    // defecto es lo bastante ancha como para renderizar en su lugar el
    // layout de barra lateral ancha de VaultPage, cuyo control de bloqueo
    // no tiene tooltip (ver VaultSidebar) como sí lo tiene el icono del
    // AppBar de móvil.
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    fakeRepository.vaultInitialized = true;
    fakeRepository.configuredPassword = 'the-real-password';

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'the-real-password');
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Bloquear bóveda'));
    await tester.pumpAndSettle();

    expect(find.text('Desbloquear bóveda'), findsOneWidget);
  });
}
