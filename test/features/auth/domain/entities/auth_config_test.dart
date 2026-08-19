import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/security/argon2_params.dart';
import 'package:nexuskeys/features/auth/domain/entities/auth_config.dart';

void main() {
  final sample = AuthConfig(
    salt: Uint8List.fromList(List.generate(16, (i) => i)),
    argon2Params: const Argon2idParams(memoryKiB: 65536, iterations: 3, parallelism: 4),
    verifierNonce: Uint8List.fromList(List.generate(12, (i) => i + 1)),
    verifierCipherText: Uint8List.fromList(List.generate(22, (i) => i + 2)),
    verifierMac: Uint8List.fromList(List.generate(16, (i) => i + 3)),
  );

  test('round-trips through JSON without losing data', () {
    final decoded = AuthConfig.fromJson(jsonDecode(jsonEncode(sample.toJson())) as Map<String, dynamic>);
    expect(decoded, sample);
  });

  test('serializes byte fields as base64, not raw arrays', () {
    final json = sample.toJson();
    expect(json['salt'], isA<String>());
    expect(base64Decode(json['salt'] as String), sample.salt);
  });
}
