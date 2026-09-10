import 'package:equatable/equatable.dart';

/// Todo lo que necesita una generación — coincide con todos los controles
/// de img/06_generator.png más "Pronunciables" de la sección del generador
/// de la especificación, que no sale en esa captura concreta pero es uno
/// de los requisitos listados explícitamente.
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

  /// Los valores por defecto del propio mockup: longitud 16, todas las
  /// clases de caracteres activadas, ambas exclusiones desactivadas.
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
