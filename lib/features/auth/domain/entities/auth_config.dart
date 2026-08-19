import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../../core/security/argon2_params.dart';
import '../../../../core/security/crypto_service.dart';

/// Everything needed to verify a master password and re-derive the vault
/// key from it, persisted locally. None of these fields are secret on
/// their own: the salt and KDF params only tune the cost of a brute-force
/// attempt, and [verifierNonce]/[verifierCipherText]/[verifierMac] only
/// authenticate under the correctly-derived key — they reveal nothing
/// without it. The master password itself is never part of this object.
class AuthConfig extends Equatable {
  const AuthConfig({
    required this.salt,
    required this.argon2Params,
    required this.verifierNonce,
    required this.verifierCipherText,
    required this.verifierMac,
  });

  final Uint8List salt;
  final Argon2idParams argon2Params;
  final Uint8List verifierNonce;
  final Uint8List verifierCipherText;
  final Uint8List verifierMac;

  EncryptedPayload get verifierPayload => EncryptedPayload(
        nonce: verifierNonce,
        cipherText: verifierCipherText,
        mac: verifierMac,
      );

  Map<String, dynamic> toJson() => {
        'salt': base64Encode(salt),
        'argon2Params': argon2Params.toJson(),
        'verifierNonce': base64Encode(verifierNonce),
        'verifierCipherText': base64Encode(verifierCipherText),
        'verifierMac': base64Encode(verifierMac),
      };

  factory AuthConfig.fromJson(Map<String, dynamic> json) => AuthConfig(
        salt: base64Decode(json['salt'] as String),
        argon2Params: Argon2idParams.fromJson(json['argon2Params'] as Map<String, dynamic>),
        verifierNonce: base64Decode(json['verifierNonce'] as String),
        verifierCipherText: base64Decode(json['verifierCipherText'] as String),
        verifierMac: base64Decode(json['verifierMac'] as String),
      );

  @override
  List<Object?> get props => [salt, argon2Params, verifierNonce, verifierCipherText, verifierMac];
}
