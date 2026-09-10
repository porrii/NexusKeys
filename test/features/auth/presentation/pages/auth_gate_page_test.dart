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

/// AuthGatePage checks these to decide whether to offer the biometric
/// unlock button; every test in this file leaves biometrics off the table
/// (that flow is covered by biometric_prompt_page_test.dart and
/// settings_page_test.dart) by reporting the device as unsupported.
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

/// Hand-written fake instead of a mocking framework — AuthRepository has
/// only four methods and this keeps the test dependency-free. Its own
/// correctness is covered separately by auth_repository_impl_test.dart;
/// this fake only needs to be controllable enough to exercise AuthGatePage's
/// navigation and error-mapping logic.
class FakeAuthRepository implements AuthRepository {
  bool vaultInitialized = false;
  String? configuredPassword;
  AuthFailureReason? nextFailureReason;

  @override
  Future<bool> isVaultInitialized() async => vaultInitialized;

  @override
  Future<AuthResult> setupMasterPassword(String password) async {
    configuredPassword = password;
    vaultInitialized = true;
    return AuthSuccess(Uint8List(32));
  }

  @override
  Future<AuthResult> verifyMasterPassword(String password) async {
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
    // VaultPage (shown after a successful unlock) and AuthGatePage's own
    // post-unlock reload() both need a real VaultRepository — registered
    // the same way production's setupServiceLocator() does.
    configureVaultDependencies(sl);
  });

  tearDown(() async {
    // The vault database file is memory-mapped by the still-open SQLCipher
    // connection; on Windows the temp dir can't be deleted until that
    // handle is released.
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
    // Below kVaultWideBreakpoint — the default test surface is wide enough
    // to render VaultPage's wide sidebar layout instead, whose lock
    // control has no tooltip (see VaultSidebar) the way the mobile
    // AppBar's icon does.
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
