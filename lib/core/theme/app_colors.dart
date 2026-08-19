import 'package:flutter/material.dart';

/// Color palette extracted directly from the official design references in
/// `/img`. Values are sampled pixel colors, not approximations — do not
/// adjust them without checking against the source mockups.
abstract final class AppColors {
  // Dark theme (default) — sampled from img/01_lock.png and img/12_theme.png.
  static const Color darkBackground = Color(0xFF020C16);
  static const Color darkSurface = Color(0xFF0B131C);
  static const Color darkSurfaceAlt = Color(0xFF10161F);
  static const Color darkBorder = Color(0xFF2A2F3A);

  // OLED theme — pure black background for burn-in reduction / battery savings.
  static const Color oledBackground = Color(0xFF000000);
  static const Color oledSurface = Color(0xFF0A0A0A);
  static const Color oledBorder = Color(0xFF232323);

  // Light theme.
  static const Color lightBackground = Color(0xFFF5F6F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE1E3E8);

  // Brand accent — shared across every theme.
  static const Color primary = Color(0xFF0D49D2);
  static const Color primaryVariant = Color(0xFF0A3AA8);

  // Semantic colors — shared across every theme.
  static const Color success = Color(0xFF1FAE5C);
  static const Color warning = Color(0xFFE0A711);
  static const Color danger = Color(0xFFE0473B);

  // Text — dark theme.
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF8A93A0);

  // Text — light theme.
  static const Color textPrimaryLight = Color(0xFF11151C);
  static const Color textSecondaryLight = Color(0xFF5C6470);

  const AppColors._();
}
