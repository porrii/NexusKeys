import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/security/argon2_params.dart';
import 'package:nexuskeys/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:nexuskeys/features/auth/domain/entities/auth_config.dart';

void main() {
  late Directory tempDir;
  late AuthLocalDataSource dataSource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nexuskeys_datasource_test_');
    dataSource = AuthLocalDataSource(overrideDirectory: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('exists() is false before anything is written', () async {
    expect(await dataSource.exists(), isFalse);
  });

  test('read() returns null before anything is written', () async {
    expect(await dataSource.read(), isNull);
  });

  test('write() then read() round-trips the config', () async {
    final config = AuthConfig(
      salt: Uint8List.fromList(List.generate(16, (i) => i)),
      argon2Params: const Argon2idParams(memoryKiB: 65536, iterations: 3, parallelism: 4),
      verifierNonce: Uint8List.fromList(List.generate(12, (i) => i)),
      verifierCipherText: Uint8List.fromList(List.generate(38, (i) => i)),
      verifierMac: Uint8List.fromList(List.generate(16, (i) => i)),
    );

    await dataSource.write(config);

    expect(await dataSource.exists(), isTrue);
    expect(await dataSource.read(), config);
  });

  test('a corrupted file surfaces as a FormatException', () async {
    final file = File('${tempDir.path}${Platform.pathSeparator}auth.json');
    await file.writeAsString('{not valid json');

    expect(() => dataSource.read(), throwsA(isA<FormatException>()));
  });
}
