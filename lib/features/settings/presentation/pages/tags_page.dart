import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/widgets/embedded_section_header.dart';
import '../../../vault/domain/entities/vault_item_type.dart';
import '../../../vault/domain/repositories/vault_repository.dart';

/// "Etiquetas" — todas las etiquetas distintas usadas ahora mismo en la
/// bóveda, con cuántos elementos la llevan y cómo renombrar o quitar una.
/// A diferencia de las categorías (la eliminada pantalla "Gestionar
/// categorías"), las etiquetas no tienen una lista gestionada aparte que
/// crear por adelantado — una etiqueta solo existe porque el
/// `VaultItem.tags` de al menos un elemento la lleva, calculado
/// directamente de [VaultRepository.currentItems] — así que
/// renombrar/borrar una aquí significa editar todos los elementos que la
/// llevan, no una fila en su propia tabla.
///
/// Ningún mockup de referencia muestra esto como su propia pantalla de
/// tamaño móvil — solo aparece como destino de la barra lateral en
/// img/13_tablet.png y img/14_windows.png. Esto le da primero un sitio
/// real donde vivir en móvil, por delante del layout de pantalla ancha que
/// lo mostrará directamente en esa barra lateral.
class TagsPage extends StatefulWidget {
  const TagsPage({super.key, this.embedded = false});

  /// True en los layouts anchos (img/13_tablet.png, img/14_windows.png),
  /// donde esto se renderiza en línea junto a la barra lateral en vez de
  /// tras su propio Scaffold/AppBar al que se llega empujando una ruta
  /// sobre todo lo demás.
  final bool embedded;

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  final VaultRepository _vault = sl<VaultRepository>();

  Map<String, int> _tagCounts() {
    final counts = <String, int>{};
    for (final item in _vault.currentItems) {
      for (final tag in item.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> _renameTag(String oldName) async {
    final newName = await _promptForName(title: 'Renombrar etiqueta', initial: oldName);
    if (newName == null) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return;

    for (final item in _vault.currentItems.where((i) => i.tags.contains(oldName)).toList()) {
      final updatedTags = [
        for (final tag in item.tags) tag == oldName ? trimmed : tag,
      ];
      await _vault.update(item.copyWith(tags: updatedTags));
    }
    if (mounted) setState(() {});
  }

  Future<void> _deleteTag(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar esta etiqueta?'),
        content: Text('Se quitará de todos los elementos que la tengan. "$name" no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;

    for (final item in _vault.currentItems.where((i) => i.tags.contains(name)).toList()) {
      final updatedTags = item.tags.where((tag) => tag != name).toList();
      await _vault.update(item.copyWith(tags: updatedTags));
    }
    if (mounted) setState(() {});
  }

  Future<String?> _promptForName({required String title, String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre de la etiqueta'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final counts = _tagCounts();
    final tags = counts.keys.toList()..sort();

    final body = SafeArea(
      top: !widget.embedded,
      child: Column(
        children: [
          if (widget.embedded) const EmbeddedSectionHeader('Etiquetas'),
          Expanded(
            child: tags.isEmpty
                ? Center(
                    child: Text(
                      'Ningún elemento tiene etiquetas todavía',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      final tag = tags[index];
                      return _TagRow(
                        color: VaultItemType.values[index % VaultItemType.values.length].color,
                        label: tag,
                        count: counts[tag]!,
                        onRename: () => _renameTag(tag),
                        onDelete: () => _deleteTag(tag),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Etiquetas')), body: body);
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.color,
    required this.label,
    required this.count,
    required this.onRename,
    required this.onDelete,
  });

  final Color color;
  final String label;
  final int count;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.label_outline, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: theme.textTheme.bodyLarge, overflow: TextOverflow.ellipsis),
            ),
            Text('$count', style: theme.textTheme.bodyMedium),
            PopupMenuButton<void Function()>(
              icon: const Icon(Icons.more_vert),
              onSelected: (action) => action(),
              itemBuilder: (context) => [
                PopupMenuItem(value: onRename, child: const Text('Renombrar')),
                PopupMenuItem(value: onDelete, child: const Text('Eliminar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
