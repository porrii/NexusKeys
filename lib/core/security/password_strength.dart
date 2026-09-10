import 'dart:math';

import 'package:flutter/material.dart';

/// Una clasificación de fortaleza guiada por bits de entropía en vez de
/// por una heurística tosca — ver [estimateEntropyBits] para contraseñas
/// guardadas/tecleadas y [exactEntropyBits] para las que la app acaba de
/// generar (donde el conjunto de caracteres real se conoce exactamente, no
/// se infiere de la cadena).
enum PasswordStrength {
  empty(label: '', segments: 0, color: Color(0xFF5C6470)),
  veryWeak(label: 'Muy débil', segments: 1, color: Color(0xFFE0473B)),
  weak(label: 'Débil', segments: 2, color: Color(0xFFE0473B)),
  medium(label: 'Media', segments: 3, color: Color(0xFFE0A711)),
  strong(label: 'Fuerte', segments: 4, color: Color(0xFF1FAE5C)),
  veryStrong(label: 'Muy fuerte', segments: 5, color: Color(0xFF1FAE5C));

  const PasswordStrength({required this.label, required this.segments, required this.color});

  final String label;

  /// Cuántas de las 5 barras del medidor de fortaleza de
  /// [img/06_generator.png] deben rellenarse.
  final int segments;
  final Color color;
}

PasswordStrength classifyEntropyBits(double bits) {
  if (bits <= 0) return PasswordStrength.empty;
  if (bits < 30) return PasswordStrength.veryWeak;
  if (bits < 45) return PasswordStrength.weak;
  if (bits < 65) return PasswordStrength.medium;
  if (bits < 90) return PasswordStrength.strong;
  return PasswordStrength.veryStrong;
}

/// Aproxima la entropía de una contraseña tecleada/guardada infiriendo de
/// qué clases de caracteres tira — no es un análisis de patrones real (sin
/// detección de diccionario ni de recorridos de teclado), solo lo justo
/// para distinguir una contraseña corta de un solo caso de una larga y
/// mezclada. Suficiente para una pantalla de detalles; [exactEntropyBits]
/// es la versión precisa que usa el Generador, que conoce el conjunto de
/// caracteres real en vez de inferirlo.
double estimateEntropyBits(String password) {
  if (password.isEmpty) return 0;

  var charsetSize = 0;
  if (RegExp(r'[a-z]').hasMatch(password)) charsetSize += 26;
  if (RegExp(r'[A-Z]').hasMatch(password)) charsetSize += 26;
  if (RegExp(r'[0-9]').hasMatch(password)) charsetSize += 10;
  if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) charsetSize += 32;
  if (charsetSize == 0) return 0;

  return exactEntropyBits(length: password.length, charsetSize: charsetSize);
}

/// bits = length * log2(charsetSize) — la fórmula estándar de la entropía
/// de una cadena uniformemente aleatoria tomada de un charset de ese
/// tamaño.
double exactEntropyBits({required int length, required int charsetSize}) {
  if (length <= 0 || charsetSize <= 1) return 0;
  return length * (log(charsetSize) / ln2);
}

PasswordStrength evaluatePasswordStrength(String password) =>
    classifyEntropyBits(estimateEntropyBits(password));

/// Una tasa de referencia muy citada para un ataque *offline* rápido (p.
/// ej. un clúster de GPU contra un objetivo filtrado y mal hasheado) —
/// usada solo para dar al usuario una idea intuitiva de la escala de la
/// fortaleza de una contraseña si la reutiliza en otro sitio. No tiene
/// nada que ver con la bóveda de esta app, que de entrada nunca expone
/// nada a fuerza bruta (Argon2id + AES-GCM).
const double _referenceGuessesPerSecond = 1e10;

/// Tiempo medio para adivinar un secreto uniformemente aleatorio con
/// [entropyBits] de entropía: la mitad del espacio de claves, a
/// [guessesPerSecond].
String estimateCrackTime(double entropyBits, {double guessesPerSecond = _referenceGuessesPerSecond}) {
  if (entropyBits <= 0) return '—';

  final double seconds = pow(2, entropyBits) / (2 * guessesPerSecond);
  return _formatDuration(seconds);
}

String _formatDuration(double seconds) {
  const minute = 60.0;
  const hour = minute * 60;
  const day = hour * 24;
  const month = day * 30;
  const year = day * 365;
  const century = year * 100;

  if (seconds < 1) return 'Instantáneo';
  if (seconds < minute) return '${seconds.round()} segundos';
  if (seconds < hour) return '${(seconds / minute).round()} minutos';
  if (seconds < day) return '${(seconds / hour).round()} horas';
  if (seconds < month) return '${(seconds / day).round()} días';
  if (seconds < year) return '${(seconds / month).round()} meses';
  if (seconds < century) return '${(seconds / year).round()} años';
  if (seconds < century * 1e6) return '${(seconds / century).round()} siglos';
  return 'Miles de millones de años';
}
