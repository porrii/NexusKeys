import 'package:equatable/equatable.dart';

/// Everything a generation run needs — matches every control on
/// img/06_generator.png plus "Pronunciables" from the spec's generator
/// section, which isn't in that particular screenshot but is one of the
/// explicitly listed requirements.
class GeneratorOptions extends Equatable {
  const GeneratorOptions({
    required this.length,
    required this.useUppercase,
    required this.useLowercase,
    required this.useNumbers,
    required this.useSymbols,
    required this.excludeAmbiguous,
    required this.excludeRepeated,
    required this.pronounceable,
  });

  /// The mockup's own defaults: length 16, every character class on,
  /// both exclusions off.
  factory GeneratorOptions.recommended() => const GeneratorOptions(
        length: 16,
        useUppercase: true,
        useLowercase: true,
        useNumbers: true,
        useSymbols: true,
        excludeAmbiguous: false,
        excludeRepeated: false,
        pronounceable: false,
      );

  static const minLength = 4;
  static const maxLength = 64;

  final int length;
  final bool useUppercase;
  final bool useLowercase;
  final bool useNumbers;
  final bool useSymbols;
  final bool excludeAmbiguous;
  final bool excludeRepeated;
  final bool pronounceable;

  bool get hasAnyCharacterClassSelected => useUppercase || useLowercase || useNumbers || useSymbols;

  GeneratorOptions copyWith({
    int? length,
    bool? useUppercase,
    bool? useLowercase,
    bool? useNumbers,
    bool? useSymbols,
    bool? excludeAmbiguous,
    bool? excludeRepeated,
    bool? pronounceable,
  }) {
    return GeneratorOptions(
      length: length ?? this.length,
      useUppercase: useUppercase ?? this.useUppercase,
      useLowercase: useLowercase ?? this.useLowercase,
      useNumbers: useNumbers ?? this.useNumbers,
      useSymbols: useSymbols ?? this.useSymbols,
      excludeAmbiguous: excludeAmbiguous ?? this.excludeAmbiguous,
      excludeRepeated: excludeRepeated ?? this.excludeRepeated,
      pronounceable: pronounceable ?? this.pronounceable,
    );
  }

  @override
  List<Object?> get props => [
        length,
        useUppercase,
        useLowercase,
        useNumbers,
        useSymbols,
        excludeAmbiguous,
        excludeRepeated,
        pronounceable,
      ];
}
