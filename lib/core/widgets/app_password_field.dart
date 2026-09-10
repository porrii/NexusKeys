import 'package:flutter/material.dart';

/// Un campo de texto para introducir una contraseña maestra / PIN con un
/// botón de mostrar/ocultar. Reutilizado por la pantalla de bloqueo, el
/// cambio de contraseña maestra y cualquier formulario futuro que recoja
/// un secreto.
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    required this.controller,
    required this.hintText,
    super.key,
    this.autofocus = false,
    this.onSubmitted,
    this.trailing,
  });

  final TextEditingController controller;
  final String hintText;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  /// Una acción extra que se muestra antes del botón de visibilidad — p.
  /// ej. el botón integrado de "generar una contraseña" en el formulario
  /// de nuevo/editar elemento.
  final Widget? trailing;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      obscureText: _obscured,
      textInputAction: TextInputAction.done,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        hintText: widget.hintText,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.trailing != null) widget.trailing!,
            IconButton(
              icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscured = !_obscured),
            ),
          ],
        ),
      ),
    );
  }
}
