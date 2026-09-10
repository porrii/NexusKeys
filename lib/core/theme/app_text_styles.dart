import 'package:flutter/material.dart';

/// Escala tipográfica común a todas las pantallas. Los mockups de
/// referencia usan la sans-serif por defecto de la plataforma
/// (Roboto/Segoe UI), así que no se incluye ninguna familia de fuente
/// propia — así la app es más ligera y se evita introducir un aspecto que
/// no esté en `/img`.
abstract final class AppTextStyles {
  static const TextStyle appTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  const AppTextStyles._();
}
