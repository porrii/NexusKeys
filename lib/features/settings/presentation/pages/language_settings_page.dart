import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// "Idioma" de img/08_settings.png. La especificación pide que la app esté
/// "preparada para la internacionalización" sin exigir todavía soporte
/// multi-idioma completo — esto muestra la única opción real (Español) en
/// vez de un simple "próximamente", ya que de verdad hay un ajuste actual
/// que mostrar, solo que aún no se puede cambiar a otra cosa.
class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key, this.embedded = false});

  /// True cuando SettingsPage la renderiza en línea en el layout ancho en
  /// vez de empujarla como su propia ruta — se salta el Scaffold/AppBar,
  /// ya que el padre ya aporta una cabecera (con flecha de volver)
  /// alrededor.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Un ListView, no una Card suelta centrada/estirada en el body: con un
    // solo idioma no hay nada que hacer scroll, pero dimensionarse al
    // contenido (como también hace la lista de opciones de
    // ThemeSettingsPage) evita que esto se estire para llenar todo el
    // panel como haría una Card pelada cuando se renderiza embebida dentro
    // de un Expanded — el mismo arreglo tanto con un idioma como con
    // varios.
    final list = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.primary),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(child: Text('Español', style: theme.textTheme.bodyLarge)),
                const Icon(Icons.check_circle, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );

    if (embedded) return list;
    return Scaffold(
      appBar: AppBar(title: const Text('Idioma')),
      body: SafeArea(child: list),
    );
  }
}
