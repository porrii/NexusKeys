import 'dart:typed_data';

import 'argon2_params.dart';

/// El resultado de un cifrado AES-256-GCM: todo lo necesario para
/// descifrar, nada de ello secreto salvo [cipherText] (el nonce y el MAC
/// se pueden guardar junto a él sin problema).
class EncryptedPayload {
  const EncryptedPayload({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final Uint8List nonce;
  final Uint8List cipherText;
  final Uint8List mac;
}

/// La lanza [CryptoService.decrypt] cuando el MAC no coincide — o la clave
/// es incorrecta o se manipularon los datos. Quien la recibe no debe
/// distinguir entre esos dos casos en los mensajes de cara al usuario.
class AuthenticationFailedException implements Exception {
  const AuthenticationFailedException();

  @override
  String toString() => 'AuthenticationFailedException: decryption failed integrity check';
}

/// Todas las primitivas criptográficas que necesita la app, aisladas tras
/// una única interfaz para que el resto del código nunca toque
/// `package:cryptography` directamente. Implementada por [CryptoServiceImpl].
abstract interface class CryptoService {
  /// Deriva una clave de 32 bytes a partir de [password] y [salt] usando
  /// Argon2id. Las mismas entradas producen siempre la misma salida — eso
  /// es lo que hace posible verificar la contraseña maestra sin
  /// guardarla.
  Future<Uint8List> deriveKey({
    required String password,
    required Uint8List salt,
    required Argon2idParams params,
  });

  /// Bytes aleatorios criptográficamente seguros (CSPRNG), aptos para
  /// salts, nonces y claves de cifrado.
  Uint8List randomBytes(int length);

  /// Cifra [plainText] con AES-256-GCM bajo [key] (debe ser de 32 bytes).
  /// Se genera un nonce aleatorio nuevo en cada llamada.
  Future<EncryptedPayload> encrypt({
    required Uint8List plainText,
    required Uint8List key,
  });

  /// Descifra un payload producido por [encrypt]. Lanza
  /// [AuthenticationFailedException] si [key] es incorrecta o los datos se
  /// manipularon.
  Future<Uint8List> decrypt({
    required EncryptedPayload payload,
    required Uint8List key,
  });

  /// Resumen SHA-512, usado para checksums de integridad no secretos (p.
  /// ej. el formato de exportación `.nexus`).
  Future<Uint8List> sha512(Uint8List data);
}
