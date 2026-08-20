import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/database/vault_session.dart';

void main() {
  late Directory tempDir;
  late VaultSession session;

  final key = Uint8List.fromList(List.generate(32, (i) => i));

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nexuskeys_vault_session_test_');
    session = VaultSession(overrideDirectory: tempDir);
  });

  tearDown(() async {
    session.lock();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('starts locked', () {
    expect(session.isUnlocked, isFalse);
  });

  test('reading database while locked throws StateError', () {
    expect(() => session.database, throwsStateError);
  });

  test('unlock() opens the database and marks the session unlocked', () async {
    await session.unlock(key);

    expect(session.isUnlocked, isTrue);
    expect(session.database, isNotNull);
  });

  test('lock() closes the database and marks the session locked again', () async {
    await session.unlock(key);
    session.lock();

    expect(session.isUnlocked, isFalse);
    expect(() => session.database, throwsStateError);
  });

  test('unlocking twice closes the first connection before opening the second', () async {
    await session.unlock(key);
    final firstDatabase = session.database;

    await session.unlock(key);

    expect(session.database, isNot(same(firstDatabase)));
  });
}
