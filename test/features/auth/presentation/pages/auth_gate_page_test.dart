import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/di/service_locator.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/auth/domain/entities/auth_result.dart';
import 'package:nexuskeys/features/auth/domain/repositories/auth_repository.dart';
import 'package:nexuskeys/features/auth/presentation/pages/auth_gate_page.dart';

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
}

void main() {
  late FakeAuthRepository fakeRepository;

  setUp(() async {
    fakeRepository = FakeAuthRepository();
    await sl.reset();
    sl.registerSingleton<AuthRepository>(fakeRepository);
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

  testWidgets('creating a vault navigates through to the vault placeholder', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear nueva bóveda'));
    await tester.pumpAndSettle();
    expect(find.text('Crear contraseña maestra'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'a-strong-password');
    await tester.enterText(find.byType(TextField).last, 'a-strong-password');
    await tester.tap(find.text('Crear bóveda'));
    await tester.pumpAndSettle();

    expect(find.text('Bóveda desbloqueada'), findsOneWidget);
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

  testWidgets('the correct password unlocks into the vault placeholder', (tester) async {
    fakeRepository.vaultInitialized = true;
    fakeRepository.configuredPassword = 'the-real-password';

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'the-real-password');
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();

    expect(find.text('Bóveda desbloqueada'), findsOneWidget);
  });

  testWidgets('locking from the vault placeholder returns to the lock screen', (tester) async {
    fakeRepository.vaultInitialized = true;
    fakeRepository.configuredPassword = 'the-real-password';

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'the-real-password');
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bloquear'));
    await tester.pumpAndSettle();

    expect(find.text('Desbloquear bóveda'), findsOneWidget);
  });
}
