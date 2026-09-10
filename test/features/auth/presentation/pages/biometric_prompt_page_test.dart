import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/di/service_locator.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/auth/domain/services/biometric_service.dart';
import 'package:nexuskeys/features/auth/domain/services/vault_key_store.dart';
import 'package:nexuskeys/features/auth/presentation/pages/biometric_prompt_page.dart';

// La lógica propia de BiometricPromptPage nunca toca un canal de
// plataforma directamente — el prompt biométrico real lo muestra de forma
// nativa BiometricService.authenticate y (solo la primera vez por proceso
// de la app, según hasWarmedUpCipher) el propio VaultKeyStore.read() (ver
// SecureVaultKeyStore) — así que con fakes de ambos basta para que estos
// tests ejerciten todas las ramas de la propia página.
class _FakeBiometricService implements BiometricService {
  _FakeBiometricService({this.confirms = true});

  final bool confirms;
  int authenticateCalls = 0;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> authenticate({required String reason}) async {
    authenticateCalls++;
    return confirms;
  }
}

class _FakeVaultKeyStore implements VaultKeyStore {
  _FakeVaultKeyStore({this.keyToReturn, bool warmedUp = false}) : _warmedUp = warmedUp; // ignore: prefer_initializing_formals

  final Uint8List? keyToReturn;
  int readCalls = 0;
  bool _warmedUp;

  @override
  bool get hasWarmedUpCipher => _warmedUp;

  @override
  Future<bool> get hasStoredKey async => keyToReturn != null;

  @override
  Future<void> save(Uint8List vaultKey) async {}

  @override
  Future<Uint8List?> read() async {
    readCalls++;
    // Refleja a SecureVaultKeyStore: llegar a un return real significa que
    // el almacenamiento subyacente se autenticó (si le hacía falta) y ya
    // está "caliente".
    _warmedUp = true;
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
    sl.registerLazySingleton<BiometricService>(_FakeBiometricService.new);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const BiometricPromptPage()));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar identidad'), findsOneWidget);
    expect(find.text('Usa tu huella dactilar para continuar'), findsOneWidget);
    expect(find.byIcon(Icons.fingerprint), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets(
    'a cold VaultKeyStore (not yet warmed up) skips BiometricService and lets read() show its own prompt',
    (tester) async {
      final expectedKey = Uint8List.fromList([1, 2, 3, 4]);
      final fakeService = _FakeBiometricService();
      final fakeStore = _FakeVaultKeyStore(keyToReturn: expectedKey);
      sl.registerLazySingleton<VaultKeyStore>(() => fakeStore);
      sl.registerLazySingleton<BiometricService>(() => fakeService);
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, navigatorKey: navigatorKey, home: const SizedBox()));
      final resultFuture = navigatorKey.currentState!.push<Uint8List>(
        MaterialPageRoute(builder: (_) => const BiometricPromptPage()),
      );
      await tester.pumpAndSettle();

      expect(await resultFuture, expectedKey);
      // Pedir también a BiometricService, además del prompt que va a
      // mostrar el propio almacenamiento, enseñaría dos prompts seguidos
      // para un solo desbloqueo.
      expect(fakeService.authenticateCalls, 0);
      expect(fakeStore.readCalls, 1);
    },
  );

  testWidgets(
    'an already-warmed-up VaultKeyStore asks BiometricService first, then still calls read()',
    (tester) async {
      final expectedKey = Uint8List.fromList([5, 6, 7, 8]);
      final fakeService = _FakeBiometricService();
      final fakeStore = _FakeVaultKeyStore(keyToReturn: expectedKey, warmedUp: true);
      sl.registerLazySingleton<VaultKeyStore>(() => fakeStore);
      sl.registerLazySingleton<BiometricService>(() => fakeService);

      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const BiometricPromptPage()));
      await tester.pumpAndSettle();

      // read() por sí solo no volvería a preguntar una vez "caliente" —
      // BiometricService es lo que hace que este intento exija de verdad
      // una huella nueva.
      expect(fakeService.authenticateCalls, 1);
      expect(fakeStore.readCalls, 1);
    },
  );

  testWidgets('a declined BiometricService.authenticate never touches an already-warm read()', (tester) async {
    final fakeStore = _FakeVaultKeyStore(keyToReturn: Uint8List.fromList([9]), warmedUp: true);
    sl.registerLazySingleton<VaultKeyStore>(() => fakeStore);
    sl.registerLazySingleton<BiometricService>(() => _FakeBiometricService(confirms: false));

    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const BiometricPromptPage()));
    await tester.pumpAndSettle();

    expect(fakeStore.readCalls, 0);
    expect(find.text('Confirmar identidad'), findsOneWidget);
  });

  testWidgets(
    'stays on screen and allows retry when read returns null, asking BiometricService from the retry on',
    (tester) async {
      final fakeStore = _FakeVaultKeyStore();
      final fakeService = _FakeBiometricService();
      sl.registerLazySingleton<VaultKeyStore>(() => fakeStore);
      sl.registerLazySingleton<BiometricService>(() => fakeService);

      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const BiometricPromptPage()));
      await tester.pumpAndSettle();

      // Primer intento: almacenamiento en frío, así que se salta
      // BiometricService en favor del prompt propio de read() (fake, aquí
      // siempre null).
      expect(fakeStore.readCalls, 1);
      expect(fakeService.authenticateCalls, 0);
      expect(find.text('Confirmar identidad'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.fingerprint));
      await tester.pumpAndSettle();

      // El almacenamiento ya está "caliente" (read() se ejecutó una vez),
      // así que este reintento pasa antes por BiometricService.
      expect(fakeStore.readCalls, 2);
      expect(fakeService.authenticateCalls, 1);
    },
  );

  testWidgets('Cancelar pops with null', (tester) async {
    sl.registerLazySingleton<VaultKeyStore>(() => _FakeVaultKeyStore());
    sl.registerLazySingleton<BiometricService>(_FakeBiometricService.new);
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
