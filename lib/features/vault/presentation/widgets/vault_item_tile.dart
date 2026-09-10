import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Una única fila de la lista de la bóveda — reproduce las filas de
/// elemento de img/03_vault.png: un avatar con color, título, subtítulo y,
/// en el borde derecho, o una estrella de favorito o un chevron.
///
/// Los elementos de ejemplo del mockup de referencia usan logos de marca
/// reales (Google, GitHub, YouTube...). Esos no son assets que este
/// proyecto tenga licencia para incluir, así que los elementos reales
/// recurren a un avatar de letra teñido con el propio campo `color` del
/// elemento — el mismo "Color/Icono" que guarda cada elemento de la bóveda
/// según la especificación — lo que mantiene el layout idéntico sin
/// fabricar arte con marcas registradas.
class VaultItemTile extends StatelessWidget {
  const VaultItemTile({
    required this.title,
    required this.subtitle,
    required this.avatarColor,
    this.isFavorite = false,
    this.alwaysShowStar = false,
    this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final Color avatarColor;
  final bool isFavorite;

  /// Las filas de resultado de img/07_search.png muestran una estrella
  /// (rellena o de contorno) en todas las filas en vez del
  /// estrella-o-chevron de img/03_vault.png — los resultados de búsqueda
  /// están todos "encontrados", así que ahí el icono del final es puramente
  /// un indicador de favorito, nunca un chevron de navegación.
  final bool alwaysShowStar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatarColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  title.isEmpty ? '?' : title[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isFavorite)
                const Icon(Icons.star, color: AppColors.warning)
              else if (alwaysShowStar)
                Icon(Icons.star_border, color: theme.textTheme.bodyMedium?.color)
              else
                Icon(Icons.chevron_right, color: theme.textTheme.bodyMedium?.color),
            ],
          ),
        ),
      ),
    );
  }
}
