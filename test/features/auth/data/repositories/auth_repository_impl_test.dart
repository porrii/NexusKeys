import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/security/argon2_params.dart';
import 'package:nexuskeys/core/security/crypto_service_impl.dart';
import 'package:nexuskeys/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:nexuskeys/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:nexuskeys/features/auth/domain/entities/auth_result.dart';

void main() {
  late Directory tempDir;
  late AuthRepositoryImpl repository;

  // Cheap Argon2id profile: these tests exercise the real KDF end-to-end,
  // but at production cost (64 MiB) the suite would take far too long on
  // constrained hardware.
  const testParams = Argon2idParams(memoryKiB: 8, iterations: 1, parallelism: 1);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nexuskeys_auth_test_');
    repository = AuthRepositoryImpl(
      cryptoService: CryptoServiceImpl(),
      localDataSource: AuthLocalDataSource(overrideDirectory: tempDir),
      argon2Params: testParams,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('a vault with no configured master password is not initialized', () async {
    expect(await repository.isVaultInitialized(), isFalse);
  });

  test('setupMasterPassword persists the auth header and returns a key', () async {
    final result = await repository.setupMasterPassword('correct-horse-battery-staple');

    expect(result, isA<AuthSuccess>());
    expect((result as AuthSuccess).vaultKey.length, 32);
    expect(await repository.isVaultInitialized(), isTrue);
  });

  test('verifyMasterPassword succeeds with the correct password', () async {
    await repository.setupMasterPassword('correct-horse-battery-staple');

    final result = await repository.verifyMasterPassword('correct-horse-battery-staple');

    expect(result, isA<AuthSuccess>());
  });

  test('verifyMasterPassword fails with the wrong password', () async {
    await repository.setupMasterPassword('correct-horse-battery-staple');

    final result = await repository.verifyMasterPassword('wrong-password');

    expect(result, isA<AuthFailure>());
    expect((result as AuthFailure).reason, AuthFailureReason.wrongPassword);
  });

  test('verifyMasterPassword reports vaultNotInitialized when never set up', () async {
    final result = await repository.verifyMasterPassword('anything');

    expect(result, isA<AuthFailure>());
    expect((result as AuthFailure).reason, AuthFailureReason.vaultNotInitialized);
  });

  test('two derived keys for the same correct password are equal', () async {
    await repository.setupMasterPassword('correct-horse-battery-staple');

    final first = await repository.verifyMasterPassword('correct-horse-battery-staple');
    final second = await repository.verifyMasterPassword('correct-horse-battery-staple');

    expect(
      (first as AuthSuccess).vaultKey,
      equals((second as AuthSuccess).vaultKey),
    );
  });

  group('changeMasterPassword', () {
    test('rejects the wrong current password without changing anything', () async {
      await repository.setupMasterPassword('old-password');

      final result = await repository.changeMasterPassword(
        currentPassword: 'not-the-old-password',
        newPassword: 'new-password',
      );

      expect(result, isA<AuthFailure>());
      expect((result as AuthFailure).reason, AuthFailureReason.wrongPassword);
      // The old password must still work — nothing was overwritten.
      expect(await repository.verifyMasterPassword('old-password'), isA<AuthSuccess>());
    });

    test('accepts the correct current password and rotates the verifier', () async {
      await repository.setupMasterPassword('old-password');

      final result = await repository.changeMasterPassword(
        currentPassword: 'old-password',
        newPassword: 'new-password',
      );

      expect(result, isA<AuthSuccess>());
      expect(await repository.verifyMasterPassword('new-password'), isA<AuthSuccess>());
      expect(
        (await repository.verifyMasterPassword('old-password') as AuthFailure).reason,
        AuthFailureReason.wrongPassword,
      );
    });
  });
}
