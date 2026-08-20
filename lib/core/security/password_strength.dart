import 'dart:math';

import 'package:flutter/material.dart';

/// A strength classification driven by entropy bits rather than a coarse
/// heuristic — see [estimateEntropyBits] for stored/typed passwords and
/// [exactEntropyBits] for ones this app just generated (where the real
/// character set is known exactly, not inferred from the string).
enum PasswordStrength {
  empty(label: '', segments: 0, color: Color(0xFF5C6470)),
  veryWeak(label: 'Muy débil', segments: 1, color: Color(0xFFE0473B)),
  weak(label: 'Débil', segments: 2, color: Color(0xFFE0473B)),
  medium(label: 'Media', segments: 3, color: Color(0xFFE0A711)),
  strong(label: 'Fuerte', segments: 4, color: Color(0xFF1FAE5C)),
  veryStrong(label: 'Muy fuerte', segments: 5, color: Color(0xFF1FAE5C));

  const PasswordStrength({required this.label, required this.segments, required this.color});

  final String label;

  /// How many of the 5 bars in [img/06_generator.png]'s strength meter
  /// should be filled.
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

/// Approximates a typed/stored password's entropy by inferring which
/// character classes it draws from — not a real pattern analysis (no
/// dictionary or keyboard-walk detection), just enough to tell a short
/// single-case password from a long mixed one. Good enough for a details
/// screen; [exactEntropyBits] is the precise version used by the Generator,
/// which knows the real character set instead of inferring it.
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

/// bits = length * log2(charsetSize) — the standard formula for the
/// entropy of a uniformly-random string drawn from a charset of that size.
double exactEntropyBits({required int length, required int charsetSize}) {
  if (length <= 0 || charsetSize <= 1) return 0;
  return length * (log(charsetSize) / ln2);
}

PasswordStrength evaluatePasswordStrength(String password) =>
    classifyEntropyBits(estimateEntropyBits(password));

/// A widely-cited reference rate for a fast *offline* attack (e.g. GPU
/// cluster against a leaked, weakly-hashed target) — used only to give the
/// user an intuitive sense of scale for a password's strength if reused
/// elsewhere. It has no bearing on this app's own vault, which never
/// exposes anything to brute-force in the first place (Argon2id + AES-GCM).
const double _referenceGuessesPerSecond = 1e10;

/// Average-case time to guess a uniformly-random secret with [entropyBits]
/// of entropy: half the keyspace, at [guessesPerSecond].
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
