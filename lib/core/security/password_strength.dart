import 'package:flutter/material.dart';

/// A coarse strength classification for display (e.g. the item details
/// screen's "Fuerte" indicator). The Generator module (img/06_generator.png)
/// adds the fuller entropy-bits/crack-time estimate on top of the same
/// character-class analysis; this only covers what's needed to show a
/// label and a colored bar elsewhere in the app.
enum PasswordStrength {
  empty(label: '', color: Color(0xFF5C6470)),
  weak(label: 'Débil', color: Color(0xFFE0473B)),
  medium(label: 'Media', color: Color(0xFFE0A711)),
  strong(label: 'Fuerte', color: Color(0xFF1FAE5C));

  const PasswordStrength({required this.label, required this.color});

  final String label;
  final Color color;
}

/// A simple length + character-class-diversity heuristic: every character
/// class present (lowercase, uppercase, digit, symbol) and every length
/// milestone reached adds one point, which then buckets into weak/medium/
/// strong. This deliberately doesn't try to be a real entropy estimate —
/// that's the Generator module's job — it only needs to be good enough to
/// tell a 4-character single-case password from a long mixed one.
PasswordStrength evaluatePasswordStrength(String password) {
  if (password.isEmpty) return PasswordStrength.empty;

  var score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  if (password.length >= 16) score++;
  if (RegExp(r'[a-z]').hasMatch(password)) score++;
  if (RegExp(r'[A-Z]').hasMatch(password)) score++;
  if (RegExp(r'[0-9]').hasMatch(password)) score++;
  if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) score++;

  if (score <= 2) return PasswordStrength.weak;
  if (score <= 4) return PasswordStrength.medium;
  return PasswordStrength.strong;
}
