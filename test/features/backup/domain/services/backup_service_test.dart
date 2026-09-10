import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/database/vault_session.dart';
import 'package:nexuskeys/core/security/argon2_params.dart';
import 'package:nexuskeys/core/security/crypto_service_impl.dart';
import 'package:nexuskeys/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:nexuskeys/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:nexuskeys/features/backup/domain/services/backup_service.dart';

void main() {
  late Directory tempDir;
  late VaultSession vaultSession;
  late AuthLocalDataSource authLocal;
  late AuthRepositoryImpl authRepository;
  late BackupService backupService;

  final vaultKey = Uint8List.fromList(List.generate(32, (i) => i));

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nexuskeys_backup_test_');
    vaultSession = VaultSession(overrideDirectory: tempDir);
    authLocal = AuthLocalDataSource(overrideDirectory: tempDir);
    final crypto = CryptoServiceImpl();
    authRepository = AuthRepositoryImpl(
      cryptoService: crypto,
      localDataSource: authLocal,
      // Argon2id barato para que la suite no pague el coste de KDF de
      // producción.
      argon2Params: const Argon2idParams(memoryKiB: 8, iterations: 1, parallelism: 1),
    );
    backupService = BackupService(
      cryptoService: crypto,
      authLocalDataSource: authLocal,
      vaultSession: vaultSession,
    );

    await authRepository.setupMasterPassword('correct-horse-battery-staple');
    await vaultSession.unlock(vaultKey);
    vaultSession.database.raw.execute(
      'INSERT INTO vault_items (type, title, created_at, updated_at) VALUES (?, ?, ?, ?);',
      ['password', 'GitHub', 1000, 1000],
    );
  });

  tearDown(() async {
    vaultSession.lock();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('buildExport throws if no master password has been configured', () async {
    final freshDir = await Directory.systemTemp.createTemp('nexuskeys_backup_fresh_');
    addTearDown(() => freshDir.delete(recursive: true));
    final freshService = BackupService(
      cryptoService: CryptoServiceImpl(),
      authLocalDataSource: AuthLocalDataSource(overrideDirectory: freshDir),
      vaultSession: VaultSession(overrideDirectory: freshDir),
    );

    expect(() => freshService.buildExport(), throwsStateError);
  });

  test('a full export round-trips back through validateImport', () async {
    final exported = await backupService.buildExport();

    final validated = await backupService.validateImport(exported, 'correct-horse-battery-staple');

    expect(validated.authConfig, await authLocal.read());
  });

  test('the export is well-formed JSON with the documented fields', () async {
    final exported = await backupService.buildExport();
    final envelope = jsonDecode(utf8.decode(exported)) as Map<String, dynamic>;

    expect(envelope['version'], BackupService.formatVersion);
    expect(envelope['createdAt'], isA<String>());
    expect(envelope['checksum'], isA<String>());
    expect(envelope['auth'], isA<Map>());
    expect(envelope['vaultData'], isA<String>());
  });

  test('validateImport rejects the wrong master password', () async {
    final exported = await backupService.buildExport();

    expect(
      () => backupService.validateImport(exported, 'wrong-password'),
      throwsA(isA<BackupImportException>()),
    );
  });

  test('validateImport rejects a tampered checksum', () async {
    final exported = await backupService.buildExport();
    final envelope = jsonDecode(utf8.decode(exported)) as Map<String, dynamic>;
    envelope['checksum'] = '0' * 128;
    final tampered = utf8.encode(jsonEncode(envelope));

    expect(
      () => backupService.validateImport(Uint8List.fromList(tampered), 'correct-horse-battery-staple'),
      throwsA(isA<BackupImportException>()),
    );
  });

  test('validateImport rejects an incompatible format version', () async {
    final exported = await backupService.buildExport();
    final envelope = jsonDecode(utf8.decode(exported)) as Map<String, dynamic>;
    envelope['version'] = 999;
    final tampered = utf8.encode(jsonEncode(envelope));

    expect(
      () => backupService.validateImport(Uint8List.fromList(tampered), 'correct-horse-battery-staple'),
      throwsA(isA<BackupImportException>()),
    );
  });

  test('validateImport rejects a file that is not valid JSON', () async {
    expect(
      () => backupService.validateImport(Uint8List.fromList(utf8.encode('not json')), 'anything'),
      throwsA(isA<BackupImportException>()),
    );
  });

  test('applyImport replaces the on-disk auth header and vault database', () async {
    final exported = await backupService.buildExport();
    final validated = await backupService.validateImport(exported, 'correct-horse-battery-staple');

    // Simula otro dispositivo: borra ambos archivos primero.
    vaultSession.lock();
    final vaultFile = await vaultSession.resolveDatabaseFile();
    if (await vaultFile.exists()) await vaultFile.delete();

    await backupService.applyImport(validated);

    expect(await authLocal.read(), validated.authConfig);
    await vaultSession.unlock(vaultKey);
    final rows = vaultSession.database.raw.select('SELECT title FROM vault_items;');
    expect(rows.single['title'], 'GitHub');
  });

  test('applyImport locks the session first so the file can be overwritten', () async {
    final exported = await backupService.buildExport();
    final validated = await backupService.validateImport(exported, 'correct-horse-battery-staple');
    expect(vaultSession.isUnlocked, isTrue);

    await backupService.applyImport(validated);

    expect(vaultSession.isUnlocked, isFalse);
  });
}
