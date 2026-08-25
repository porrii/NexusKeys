import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../vault/domain/entities/vault_item_type.dart';
import '../../../vault/domain/repositories/vault_repository.dart';

/// "Etiquetas" — every distinct tag currently used across the vault, with
/// how many items carry it, and how to rename or remove one. Unlike
/// categories (the removed "Gestionar categorías" screen), tags have no
/// separate managed list to create ahead of time — a tag only exists
/// because at least one item's `VaultItem.tags` carries it, computed
/// straight from [VaultRepository.currentItems] — so renaming/deleting one
/// here means editing every item that carries it, not a row in its own
/// table.
///
/// No reference mockup shows this as its own phone-sized screen — it only
/// appears as a sidebar destination in img/13_tablet.png and
/// img/14_windows.png. This gives it a real place to live on mobile first,
/// ahead of the wide-screen layout that will surface it directly in that
/// sidebar.
class TagsPage extends StatefulWidget {
  const TagsPage({super.key});

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

    return Scaffold(
      appBar: AppBar(title: const Text('Etiquetas')),
      body: SafeArea(
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
    );
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
