import 'package:flutter/material.dart';

/// Sustituye al título del AppBar en una página que puede renderizarse
/// como pantalla completa propia (móvil, o empujada sobre la barra lateral
/// del layout ancho) o embebida directamente en el área de contenido del
/// layout ancho (img/13_tablet.png, img/14_windows.png) — TagsPage,
/// TrashPage y SettingsPage la reutilizan para que la forma embebida se
/// vea visualmente coherente entre todas.
///
/// [onBack] añade una flecha de volver a la izquierda, para una subpágina
/// embebida un nivel más adentro (p. ej. el "Tema" de Ajustes) que aún
/// necesita una forma de volver a su lista padre sin el botón de volver
/// por defecto del AppBar de una ruta empujada — omítelo para un destino
/// de barra lateral de primer nivel, que no tiene *adónde* volver.
class EmbeddedSectionHeader extends StatelessWidget {
  const EmbeddedSectionHeader(this.title, {super.key, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)),
          ),
        ],
      ),
    );
  }
}
