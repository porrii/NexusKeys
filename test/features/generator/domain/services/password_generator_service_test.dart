import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/security/crypto_service_impl.dart';
import 'package:nexuskeys/features/generator/domain/entities/generator_options.dart';
import 'package:nexuskeys/features/generator/domain/services/password_generator_service.dart';

void main() {
  final generator = PasswordGeneratorService(cryptoService: CryptoServiceImpl());

  test('produces a password of the requested length', () {
    final password = generator.generate(GeneratorOptions.recommended().copyWith(length: 24));
    expect(password, hasLength(24));
  });

  test('two generated passwords are not equal (CSPRNG, not deterministic)', () {
    final options = GeneratorOptions.recommended();
    expect(generator.generate(options), isNot(generator.generate(options)));
  });

  test('only uses letters when only useLowercase is on', () {
    final options = const GeneratorOptions(
      length: 40,
      useUppercase: false,
      useLowercase: true,
      useNumbers: false,
      useSymbols: false,
      excludeAmbiguous: false,
      excludeRepeated: false,
      pronounceable: false,
    );

    final password = generator.generate(options);

    expect(RegExp(r'^[a-z]+$').hasMatch(password), isTrue);
  });

  test('includes at least one character from every enabled class over many runs', () {
    final options = GeneratorOptions.recommended().copyWith(length: 20);
    final allGenerated = List.generate(20, (_) => generator.generate(options)).join();

    expect(RegExp('[a-z]').hasMatch(allGenerated), isTrue);
    expect(RegExp('[A-Z]').hasMatch(allGenerated), isTrue);
    expect(RegExp('[0-9]').hasMatch(allGenerated), isTrue);
    expect(RegExp(r'[^a-zA-Z0-9]').hasMatch(allGenerated), isTrue);
  });

  test('returns an empty string when no character class is selected and not pronounceable', () {
    const options = GeneratorOptions(
      length: 16,
      useUppercase: false,
      useLowercase: false,
      useNumbers: false,
      useSymbols: false,
      excludeAmbiguous: false,
      excludeRepeated: false,
      pronounceable: false,
    );

    expect(generator.generate(options), isEmpty);
  });

  group('excludeAmbiguous', () {
    test('never includes characters from the ambiguous set', () {
      final options = GeneratorOptions.recommended().copyWith(length: 60, excludeAmbiguous: true);
      const ambiguous = 'Il1O0|';

      final password = generator.generate(options);

      for (final char in ambiguous.split('')) {
        expect(password.contains(char), isFalse, reason: '"$char" should have been excluded');
      }
    });
  });

  group('excludeRepeated', () {
    test('never repeats a character', () {
      final options = GeneratorOptions.recommended().copyWith(length: 40, excludeRepeated: true);

      final password = generator.generate(options);

      expect(password.split('').toSet().length, password.length);
    });

    test('caps the length at the charset size rather than looping forever', () {
      // Digits only: 10 possible characters, but 20 requested.
      const options = GeneratorOptions(
        length: 20,
        useUppercase: false,
        useLowercase: false,
        useNumbers: true,
        useSymbols: false,
        excludeAmbiguous: false,
        excludeRepeated: true,
        pronounceable: false,
      );

      final password = generator.generate(options);

      expect(password.length, lessThanOrEqualTo(10));
      expect(password.split('').toSet().length, password.length);
    });
  });

  group('pronounceable', () {
    test('produces the requested length', () {
      final options = GeneratorOptions.recommended().copyWith(pronounceable: true, length: 12);
      expect(generator.generate(options), hasLength(12));
    });

    test('capitalizes the first letter', () {
      final options = GeneratorOptions.recommended().copyWith(pronounceable: true, length: 10);
      final password = generator.generate(options);
      expect(password[0], password[0].toUpperCase());
    });

    test('ends in a digit when useNumbers is on', () {
      final options = GeneratorOptions.recommended().copyWith(pronounceable: true, length: 10);
      final password = generator.generate(options);
      expect(RegExp(r'[0-9]$').hasMatch(password), isTrue);
    });
  });

  group('characterSetFor', () {
    test('grows as more character classes are enabled', () {
      final lowerOnly = generator.characterSetFor(
        GeneratorOptions.recommended().copyWith(
          useUppercase: false,
          useNumbers: false,
          useSymbols: false,
        ),
      );
      final full = generator.characterSetFor(GeneratorOptions.recommended());

      expect(full.length, greaterThan(lowerOnly.length));
    });

    test('shrinks when excludeAmbiguous is on', () {
      final withAmbiguous = generator.characterSetFor(GeneratorOptions.recommended());
      final withoutAmbiguous = generator.characterSetFor(
        GeneratorOptions.recommended().copyWith(excludeAmbiguous: true),
      );

      expect(withoutAmbiguous.length, lessThan(withAmbiguous.length));
    });
  });
}
