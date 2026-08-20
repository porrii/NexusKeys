import '../../../../core/security/crypto_service.dart';
import '../entities/generator_options.dart';

/// Turns [GeneratorOptions] into an actual password, using [CryptoService]'s
/// CSPRNG for every random choice — the same randomness source the rest of
/// the app's security relies on, rather than a second, bespoke one.
///
/// A single concrete class rather than interface+impl: there's exactly one
/// sensible algorithm here (no alternate data source to swap in the way
/// [VaultRepository] has SQLCipher vs. a fake), so the extra layer would
/// only add indirection without adding testability.
class PasswordGeneratorService {
  PasswordGeneratorService({required CryptoService cryptoService}) : _crypto = cryptoService;

  final CryptoService _crypto;

  static const _lower = 'abcdefghijklmnopqrstuvwxyz';
  static const _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _digits = '0123456789';
  static const _symbols = '!@#\$%^&*()-_=+?';

  /// Characters that are easy to confuse with each other in most fonts.
  static const _ambiguous = 'Il1O0|';

  static const _consonants = 'bcdfghjklmnpqrstvwxyz';
  static const _vowels = 'aeiou';

  /// The character set [generate] would draw from for these options —
  /// exposed so the UI can show real entropy (it knows the exact set used,
  /// unlike [estimateEntropyBits] which has to infer one from arbitrary
  /// text) and so it can warn before generating with an empty set.
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

    // Can't have more unique characters than the charset provides.
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

  /// A uniform random index in `[0, max)`, drawn via rejection sampling so
  /// no index is more likely than any other — `_crypto.randomBytes(1)[0] %
  /// max` alone would bias low indices whenever 256 isn't a multiple of
  /// `max`, which is most of the time.
  int _randomIndex(int max) {
    final limit = 256 - (256 % max);
    while (true) {
      final byte = _crypto.randomBytes(1)[0];
      if (byte < limit) return byte % max;
    }
  }
}
