import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:cryptography/dart.dart' show DartArgon2id;

import 'argon2_params.dart';
import 'crypto_service.dart';

/// [CryptoService] respaldado por `package:cryptography`. AES-256-GCM y
/// SHA-512 usan sus implementaciones en Dart puro / aceleradas por
/// plataforma (aceleradas en Android/iOS/macOS una vez `cryptography_flutter`
/// se registra en `main()`).
class CryptoServiceImpl implements CryptoService {
  CryptoServiceImpl() : _random = Random.secure();

  final Random _random;

  @override
  Future<Uint8List> deriveKey({
    required String password,
    required Uint8List salt,
    required Argon2idParams params,
  }) async {
    // DartArgon2id en vez de crypto.Argon2id(...) (que en Windows/desktop
    // usa por defecto su variante FFI y reparte el cálculo entre varios
    // Isolate.spawn) — maxIsolates: 0 fuerza el camino sin isolates
    // adicionales, calculando todo en el isolate que llama, con cesiones
    // cooperativas periódicas (así la UI sigue respondiendo) en vez de
    // paralelismo real. Un cuelgue real de desbloqueo se rastreó hasta ahí:
    // el propio paquete impone un timeout de 10 s por segmento cuando un
    // isolate ayudante no responde a tiempo, y esa excepción no se estaba
    // capturando en ningún sitio de la cadena de desbloqueo — evitar del
    // todo esos isolates es más robusto que solo capturar el error. Se
    // verificó que la clave derivada es exactamente la misma con o sin
    // isolates (el paralelismo es un detalle de la implementación, no
    // afecta al resultado del KDF), y el tiempo de derivación no empeora
    // de forma perceptible.
    final algorithm = DartArgon2id(
      parallelism: params.parallelism,
      memory: params.memoryKiB,
      iterations: params.iterations,
      hashLength: 32,
      maxIsolates: 0,
    );
    final secretKey = await algorithm.deriveKeyFromPassword(password: password, nonce: salt);
    return Uint8List.fromList(await secretKey.extractBytes());
  }

  @override
  Uint8List randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  @override
  Future<EncryptedPayload> encrypt({
    required Uint8List plainText,
    required Uint8List key,
  }) async {
    final algorithm = crypto.AesGcm.with256bits();
    final secretKey = crypto.SecretKey(key);
    final secretBox = await algorithm.encrypt(plainText, secretKey: secretKey);
    return EncryptedPayload(
      nonce: Uint8List.fromList(secretBox.nonce),
      cipherText: Uint8List.fromList(secretBox.cipherText),
      mac: Uint8List.fromList(secretBox.mac.bytes),
    );
  }

  @override
  Future<Uint8List> decrypt({
    required EncryptedPayload payload,
    required Uint8List key,
  }) async {
    final algorithm = crypto.AesGcm.with256bits();
    final secretKey = crypto.SecretKey(key);
    final secretBox = crypto.SecretBox(
      payload.cipherText,
      nonce: payload.nonce,
      mac: crypto.Mac(payload.mac),
    );
    try {
      final clearText = await algorithm.decrypt(secretBox, secretKey: secretKey);
      return Uint8List.fromList(clearText);
    } on crypto.SecretBoxAuthenticationError {
      throw const AuthenticationFailedException();
    }
  }

  @override
  Future<Uint8List> sha512(Uint8List data) async {
    final hash = await crypto.Sha512().hash(data);
    return Uint8List.fromList(hash.bytes);
  }
}
