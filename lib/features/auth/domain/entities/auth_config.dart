import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../../core/security/argon2_params.dart';
import '../../../../core/security/crypto_service.dart';

/// Todo lo necesario para verificar una contraseña maestra y volver a
/// derivar la clave de la bóveda a partir de ella, guardado en local.
/// Ninguno de estos campos es secreto por sí solo: el salt y los
/// parámetros del KDF solo ajustan el coste de un intento de fuerza bruta,
/// y [verifierNonce]/[verifierCipherText]/[verifierMac] solo se autentican
/// bajo la clave derivada correctamente — no revelan nada sin ella. La
/// contraseña maestra en sí nunca forma parte de este objeto.
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
