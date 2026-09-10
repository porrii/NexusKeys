import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Las secciones a las que puede navegar [VaultSidebar]. [favorites] y
/// [recent] filtran la lista de elementos en el sitio; el resto la
/// sustituyen por el contenido embebido de esa sección (junto a la barra
/// lateral, no una ruta a pantalla completa) — ver el manejo del layout
/// ancho de VaultPage.
enum VaultSidebarSection { vault, favorites, recent, tags, trash, settings }

/// La columna de navegación izquierda persistente que se muestra en los
/// layouts anchos — reproduce la barra lateral de img/13_tablet.png e
/// img/14_windows.png. Por debajo del breakpoint de tablet/escritorio,
/// esto no existe en absoluto: el móvil mantiene sin cambios su propia
/// navegación de drawer/navegación-inferior/chips-de-filtro.
class VaultSidebar extends StatelessWidget {
  const VaultSidebar({
    required this.selected,
    required this.onSelect,
    required this.onCreateItem,
    required this.onLock,
    super.key,
  });

  final VaultSidebarSection selected;
  final ValueChanged<VaultSidebarSection> onSelect;
  final VoidCallback onCreateItem;
  final VoidCallback onLock;

  static const _items = [
    (section: VaultSidebarSection.vault, icon: Icons.lock_outlined, label: 'Bóveda'),
    (section: VaultSidebarSection.favorites, icon: Icons.star_border, label: 'Favoritos'),
    (section: VaultSidebarSection.recent, icon: Icons.access_time, label: 'Recientes'),
    (section: VaultSidebarSection.tags, icon: Icons.label_outline, label: 'Etiqueta'),
    (section: VaultSidebarSection.trash, icon: Icons.delete_outline, label: 'Papelera'),
    (section: VaultSidebarSection.settings, icon: Icons.settings_outlined, label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Image.asset('assets/images/logo_mark.png', width: 28, height: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'NexusKeys',
                      style: theme.textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final item in _items)
                    _SidebarTile(
                      icon: item.icon,
                      label: item.label,
                      selected: item.section == selected,
                      onTap: () => onSelect(item.section),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onCreateItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo elemento'),
                ),
              ),
            ),
            InkWell(
              onTap: onLock,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Row(
                  children: [
                    Icon(Icons.lock_outlined, size: 16, color: theme.textTheme.bodyMedium?.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bóveda bloqueada',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? AppColors.primary : theme.textTheme.bodyLarge?.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
