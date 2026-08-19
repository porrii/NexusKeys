import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/security/argon2_params.dart';
import 'package:nexuskeys/core/security/crypto_service.dart';
import 'package:nexuskeys/core/security/crypto_service_impl.dart';

void main() {
  final crypto = CryptoServiceImpl();

  // Real Argon2id costs (64 MiB) are deliberately slow for security; tests
  // use a cheap profile so the suite stays fast while exercising the same
  // code path.
  const cheapParams = Argon2idParams(memoryKiB: 8, iterations: 1, parallelism: 1);

  group('randomBytes', () {
    test('returns the requested length', () {
      expect(crypto.randomBytes(16).length, 16);
      expect(crypto.randomBytes(32).length, 32);
    });

    test('two calls are not equal (CSPRNG, not a fixed buffer)', () {
      final a = crypto.randomBytes(32);
      final b = crypto.randomBytes(32);
      expect(a, isNot(equals(b)));
    });
  });

  group('deriveKey (Argon2id)', () {
    test('is deterministic for the same password, salt and params', () async {
      final salt = crypto.randomBytes(16);
      final a = await crypto.deriveKey(password: 'correct-horse', salt: salt, params: cheapParams);
      final b = await crypto.deriveKey(password: 'correct-horse', salt: salt, params: cheapParams);
      expect(a, equals(b));
    });

    test('a different salt produces a different key', () async {
      final a = await crypto.deriveKey(
        password: 'correct-horse',
        salt: Uint8List.fromList(List.filled(16, 1)),
        params: cheapParams,
      );
      final b = await crypto.deriveKey(
        password: 'correct-horse',
        salt: Uint8List.fromList(List.filled(16, 2)),
        params: cheapParams,
      );
      expect(a, isNot(equals(b)));
    });

    test('a different password produces a different key', () async {
      final salt = crypto.randomBytes(16);
      final a = await crypto.deriveKey(password: 'password-one', salt: salt, params: cheapParams);
      final b = await crypto.deriveKey(password: 'password-two', salt: salt, params: cheapParams);
      expect(a, isNot(equals(b)));
    });

    test('produces a 32-byte key', () async {
      final key = await crypto.deriveKey(
        password: 'correct-horse',
        salt: crypto.randomBytes(16),
        params: cheapParams,
      );
      expect(key.length, 32);
    });
  });

  group('AES-256-GCM encrypt/decrypt', () {
    test('round-trips plaintext', () async {
      final key = crypto.randomBytes(32);
      final plainText = Uint8List.fromList(utf8.encode('the quick brown fox'));

      final payload = await crypto.encrypt(plainText: plainText, key: key);
      final decrypted = await crypto.decrypt(payload: payload, key: key);

      expect(utf8.decode(decrypted), 'the quick brown fox');
    });

    test('uses a fresh nonce for every call', () async {
      final key = crypto.randomBytes(32);
      final plainText = Uint8List.fromList(utf8.encode('same message'));

      final a = await crypto.encrypt(plainText: plainText, key: key);
      final b = await crypto.encrypt(plainText: plainText, key: key);

      expect(a.nonce, isNot(equals(b.nonce)));
      expect(a.cipherText, isNot(equals(b.cipherText)));
    });

    test('decrypting with the wrong key throws AuthenticationFailedException', () async {
      final key = crypto.randomBytes(32);
      final wrongKey = crypto.randomBytes(32);
      final payload = await crypto.encrypt(
        plainText: Uint8List.fromList(utf8.encode('secret')),
        key: key,
      );

      expect(
        () => crypto.decrypt(payload: payload, key: wrongKey),
        throwsA(isA<AuthenticationFailedException>()),
      );
    });

    test('a tampered ciphertext byte is rejected', () async {
      final key = crypto.randomBytes(32);
      final payload = await crypto.encrypt(
        plainText: Uint8List.fromList(utf8.encode('secret')),
        key: key,
      );
      final tampered = EncryptedPayload(
        nonce: payload.nonce,
        cipherText: Uint8List.fromList(payload.cipherText)..[0] ^= 0xFF,
        mac: payload.mac,
      );

      expect(
        () => crypto.decrypt(payload: tampered, key: key),
        throwsA(isA<AuthenticationFailedException>()),
      );
    });

    test('a tampered MAC is rejected', () async {
      final key = crypto.randomBytes(32);
      final payload = await crypto.encrypt(
        plainText: Uint8List.fromList(utf8.encode('secret')),
        key: key,
      );
      final tampered = EncryptedPayload(
        nonce: payload.nonce,
        cipherText: payload.cipherText,
        mac: Uint8List.fromList(payload.mac)..[0] ^= 0xFF,
      );

      expect(
        () => crypto.decrypt(payload: tampered, key: key),
        throwsA(isA<AuthenticationFailedException>()),
      );
    });
  });

  group('sha512', () {
    test('matches the well-known digest of the empty string', () async {
      final digest = await crypto.sha512(Uint8List(0));
      final hex = digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(
        hex,
        'cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9c'
        'e47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e',
      );
    });

    test('is deterministic and 64 bytes long', () async {
      final data = Uint8List.fromList(utf8.encode('NexusKeys'));
      final a = await crypto.sha512(data);
      final b = await crypto.sha512(data);
      expect(a, equals(b));
      expect(a.length, 64);
    });
  });
}
