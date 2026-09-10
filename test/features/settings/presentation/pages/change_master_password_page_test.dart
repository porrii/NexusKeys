import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/database/vault_session.dart';
import 'package:nexuskeys/core/di/service_locator.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/auth/domain/entities/auth_result.dart';
import 'package:nexuskeys/features/auth/domain/repositories/auth_repository.dart';
import 'package:nexuskeys/features/settings/presentation/pages/change_master_password_page.dart';

/// Fake escrito a mano, reflejando al de auth_gate_page_test.dart.
class FakeAuthRepository implements AuthRepository {
  String configuredPassword = 'old-password';

  @override
  Future<bool> isVaultInitialized() async => true;

  @override
  Future<AuthResult> setupMasterPassword(String password) async => AuthSuccess(Uint8List(32));

  @override
  Future<AuthResult> verifyMasterPassword(String password) async {
    if (password != configuredPassword) return const AuthFailure(AuthFailureReason.wrongPassword);
    return AuthSuccess(Uint8List(32));
  }

  @override
  Future<AuthResult> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword != configuredPassword) {
      return const AuthFailure(AuthFailureReason.wrongPassword);
    }
    configuredPassword = newPassword;
    return AuthSuccess(Uint8List(32));
  }

  @override
  Future<AuthResult> deleteVault({required String password}) =>
      throw UnimplementedError();
}

void main() {
  late Directory tempDir;
  late VaultSession vaultSession;
  late FakeAuthRepository authRepository;

  final unlockKey = Uint8List.fromList(List.generate(32, (i) => i));

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nexuskeys_change_pw_test_');
    vaultSession = VaultSession(overrideDirectory: tempDir);
    await vaultSession.unlock(unlockKey);
    authRepository = FakeAuthRepository();

    await sl.reset();
    sl.registerSingleton<AuthRepository>(authRepository);
    sl.registerSingleton<VaultSession>(vaultSession);
  });

  tearDown(() async {
    vaultSession.lock();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  testWidgets('rejects a new password shorter than the minimum length', (tester) async {
    await tester.pumpWidget(wrap(const ChangeMasterPasswordPage()));

    await tester.enterText(find.byType(TextField).at(0), 'old-password');
    await tester.enterText(find.byType(TextField).at(1), 'short');
    await tester.enterText(find.byType(TextField).at(2), 'short');
    await tester.tap(find.text('Guardar'));
    await tester.pump();

    expect(find.textContaining('al menos'), findsOneWidget);
  });

  testWidgets('rejects mismatched new passwords', (tester) async {
    await tester.pumpWidget(wrap(const ChangeMasterPasswordPage()));

    await tester.enterText(find.byType(TextField).at(0), 'old-password');
    await tester.enterText(find.byType(TextField).at(1), 'a-new-strong-password');
    await tester.enterText(find.byType(TextField).at(2), 'a-different-password');
    await tester.tap(find.text('Guardar'));
    await tester.pump();

    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });

  testWidgets('shows an error when the current password is wrong', (tester) async {
    await tester.pumpWidget(wrap(const ChangeMasterPasswordPage()));

    await tester.enterText(find.byType(TextField).at(0), 'not-the-old-password');
    await tester.enterText(find.byType(TextField).at(1), 'a-new-strong-password');
    await tester.enterText(find.byType(TextField).at(2), 'a-new-strong-password');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('La contraseña actual no es correcta'), findsOneWidget);
  });

  testWidgets('succeeds, rekeys the vault, and pops with a confirmation', (tester) async {
    await tester.pumpWidget(wrap(
      Navigator(
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChangeMasterPasswordPage()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'old-password');
    await tester.enterText(find.byType(TextField).at(1), 'a-new-strong-password');
    await tester.enterText(find.byType(TextField).at(2), 'a-new-strong-password');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Contraseña maestra actualizada'), findsOneWidget);
    expect(authRepository.configuredPassword, 'a-new-strong-password');
  });
}
