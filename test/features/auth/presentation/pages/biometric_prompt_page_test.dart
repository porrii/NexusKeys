import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/di/service_locator.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/auth/domain/services/vault_key_store.dart';
import 'package:nexuskeys/features/auth/presentation/pages/biometric_prompt_page.dart';

// BiometricPromptPage's own logic never touches a platform channel directly
// — the real biometric prompt is shown natively by VaultKeyStore.read()
// (see SecureVaultKeyStore), so a fake VaultKeyStore is all these tests
// need to exercise every branch of the page itself.
class _FakeVaultKeyStore implements VaultKeyStore {
  _FakeVaultKeyStore({this.keyToReturn});

  final Uint8List? keyToReturn;
  int readCalls = 0;

  @override
  Future<bool> get hasStoredKey async => keyToReturn != null;

  @override
  Future<void> save(Uint8List vaultKey) async {}

  @override
  Future<Uint8List?> read() async {
    readCalls++;
    return keyToReturn;
  }

  @override
  Future<void> clear() async {}
}

void main() {
  tearDown(() async {
    await sl.reset();
  });

  testWidgets('renders every element from img/10_biometric.png', (tester) async {
    sl.registerLazySingleton<VaultKeyStore>(() => _FakeVaultKeyStore());
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const BiometricPromptPage()));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar identidad'), findsOneWidget);
    expect(find.text('Usa tu huella dactilar para continuar'), findsOneWidget);
    expect(find.byIcon(Icons.fingerprint), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('pops with the vault key once VaultKeyStore.read succeeds', (tester) async {
    final expectedKey = Uint8List.fromList([1, 2, 3, 4]);
    sl.registerLazySingleton<VaultKeyStore>(() => _FakeVaultKeyStore(keyToReturn: expectedKey));
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, navigatorKey: navigatorKey, home: const SizedBox()));
    final resultFuture = navigatorKey.currentState!.push<Uint8List>(
      MaterialPageRoute(builder: (_) => const BiometricPromptPage()),
    );
    await tester.pumpAndSettle();

    expect(await resultFuture, expectedKey);
  });

  testWidgets('stays on screen and allows retry when read returns null', (tester) async {
    final fakeStore = _FakeVaultKeyStore();
    sl.registerLazySingleton<VaultKeyStore>(() => fakeStore);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const BiometricPromptPage()));
    await tester.pumpAndSettle();

    expect(fakeStore.readCalls, 1);
    expect(find.text('Confirmar identidad'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.fingerprint));
    await tester.pumpAndSettle();

    expect(fakeStore.readCalls, 2);
  });

  testWidgets('Cancelar pops with null', (tester) async {
    sl.registerLazySingleton<VaultKeyStore>(() => _FakeVaultKeyStore());
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, navigatorKey: navigatorKey, home: const SizedBox()));
    final resultFuture = navigatorKey.currentState!.push<Uint8List>(
      MaterialPageRoute(builder: (_) => const BiometricPromptPage()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(await resultFuture, isNull);
  });
}
