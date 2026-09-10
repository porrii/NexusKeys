import '../../../../core/security/crypto_service.dart';
import '../entities/generator_options.dart';

/// Convierte [GeneratorOptions] en una contraseña real, usando el CSPRNG
/// de [CryptoService] para cada elección aleatoria — la misma fuente de
/// aleatoriedad de la que depende el resto de la seguridad de la app, en
/// vez de una segunda a medida.
///
/// Una única clase concreta en vez de interfaz+implementación: aquí hay
/// exactamente un algoritmo sensato (ninguna fuente de datos alternativa
/// que intercambiar como [VaultRepository] tiene SQLCipher frente a un
/// fake), así que la capa extra solo añadiría indirección sin añadir
/// testabilidad.
class PasswordGeneratorService {
  PasswordGeneratorService({required CryptoService cryptoService}) : _crypto = cryptoService;

  final CryptoService _crypto;

  static const _lower = 'abcdefghijklmnopqrstuvwxyz';
  static const _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _digits = '0123456789';
  static const _symbols = '!@#\$%^&*()-_=+?';

  /// Caracteres fáciles de confundir entre sí en la mayoría de fuentes.
  static const _ambiguous = 'Il1O0|';

  static const _consonants = 'bcdfghjklmnpqrstvwxyz';
  static const _vowels = 'aeiou';

  /// El conjunto de caracteres del que tiraría [generate] para estas
  /// opciones — expuesto para que la UI pueda mostrar entropía real
  /// (conoce el conjunto exacto usado, a diferencia de
  /// [estimateEntropyBits] que tiene que inferir uno de texto arbitrario)
  /// y para que pueda avisar antes de generar con un conjunto vacío.
  String characterSetFor(GeneratorOptions options) {
    var charset = '';
    if (options.useLowercase) charset += _lower;
    if (options.useUppercase) charset += _upper;
    if (options.useNumbers) charset += _digits;
    if (options.useSymbols) charset += _symbols;
    if (options.excludeAmbiguous) {
      charset = charset.split('').where((c) => !_ambiguous.contains(c)).join();
    }
    return charset;
  }

  String generate(GeneratorOptions options) {
    if (options.pronounceable) return _generatePronounceable(options);
    return _generateRandom(options);
  }

  String _generateRandom(GeneratorOptions options) {
    final charset = characterSetFor(options);
    if (charset.isEmpty) return '';

    // No puede haber más caracteres únicos de los que da el charset.
    final targetLength =
        options.excludeRepeated ? (options.length < charset.length ? options.length : charset.length) : options.length;

    final buffer = StringBuffer();
    final used = <String>{};
    while (buffer.length < targetLength) {
      final char = charset[_randomIndex(charset.length)];
      if (options.excludeRepeated && !used.add(char)) continue;
      buffer.write(char);
    }
    return buffer.toString();
  }

  String _generatePronounceable(GeneratorOptions options) {
    final buffer = StringBuffer();
    var wantConsonant = true;
    while (buffer.length < options.length) {
      final pool = wantConsonant ? _consonants : _vowels;
      buffer.write(pool[_randomIndex(pool.length)]);
      wantConsonant = !wantConsonant;
    }

    var result = buffer.toString();
    if (result.isNotEmpty) {
      result = result[0].toUpperCase() + result.substring(1);
    }
    if (options.useNumbers && result.length >= 2) {
      result = result.substring(0, result.length - 1) + _digits[_randomIndex(_digits.length)];
    }
    return result;
  }

  /// Un índice aleatorio uniforme en `[0, max)`, obtenido por muestreo con
  /// rechazo para que ningún índice sea más probable que otro —
  /// `_crypto.randomBytes(1)[0] % max` por sí solo sesgaría hacia los
  /// índices bajos siempre que 256 no sea múltiplo de `max`, que es casi
  /// siempre.
  int _randomIndex(int max) {
    final limit = 256 - (256 % max);
    while (true) {
      final byte = _crypto.randomBytes(1)[0];
      if (byte < limit) return byte % max;
    }
  }
}
