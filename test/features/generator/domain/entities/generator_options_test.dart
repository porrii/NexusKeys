import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/features/generator/domain/entities/generator_options.dart';

void main() {
  test('recommended() matches the mockup defaults', () {
    final options = GeneratorOptions.recommended();

    expect(options.length, 16);
    expect(options.useUppercase, isTrue);
    expect(options.useLowercase, isTrue);
    expect(options.useNumbers, isTrue);
    expect(options.useSymbols, isTrue);
    expect(options.excludeAmbiguous, isFalse);
    expect(options.excludeRepeated, isFalse);
    expect(options.pronounceable, isFalse);
  });

  test('hasAnyCharacterClassSelected is false only when every class is off', () {
    final none = GeneratorOptions.recommended().copyWith(
      useUppercase: false,
      useLowercase: false,
      useNumbers: false,
      useSymbols: false,
    );
    expect(none.hasAnyCharacterClassSelected, isFalse);

    expect(none.copyWith(useNumbers: true).hasAnyCharacterClassSelected, isTrue);
  });

  test('copyWith overrides only the given fields', () {
    final options = GeneratorOptions.recommended().copyWith(length: 24, useSymbols: false);

    expect(options.length, 24);
    expect(options.useSymbols, isFalse);
    expect(options.useUppercase, isTrue);
  });

  test('two options with identical fields are equal', () {
    expect(GeneratorOptions.recommended(), GeneratorOptions.recommended());
  });
}
