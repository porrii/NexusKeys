import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/vault_item.dart';
import '../widgets/item_field_card.dart';

/// Read-only view of a vault item — reproduces img/04_item_details.png.
/// "Editar" hands off to [EditVaultItemPage] (img/05_new_item.png's form,
/// reused for editing); "Eliminar" is the one place deletion is reachable
/// from, per the mockup.
///
/// Stateful so a favorite toggle or an edit updates what's on screen
/// immediately, without popping back to the list and re-opening.
class ItemDetailsPage extends StatefulWidget {
  const ItemDetailsPage({
    required this.item,
    super.key,
    this.onToggleFavorite,
    this.onEdit,
    this.onDelete,
  });

  final VaultItem item;

  /// Called with the new value; the repository call is the caller's job.
  final ValueChanged<bool>? onToggleFavorite;

  /// Pushes the edit form and resolves with the saved item, or null if the
  /// user backed out without saving.
  final Future<VaultItem?> Function()? onEdit;

  final VoidCallback? onDelete;

  @override
  State<ItemDetailsPage> createState() => _ItemDetailsPageState();
}

class _ItemDetailsPageState extends State<ItemDetailsPage> {
  late VaultItem _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiado')),
    );
  }

  void _toggleFavorite() {
    final newValue = !_item.isFavorite;
    setState(() => _item = _item.copyWith(isFavorite: newValue));
    widget.onToggleFavorite?.call(newValue);
  }

  Future<void> _openEdit() async {
    final updated = await widget.onEdit?.call();
    if (updated != null && mounted) setState(() => _item = updated);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este elemento?'),
        content: const Text('Se moverá a la papelera.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed == true) widget.onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = _item;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(item.isFavorite ? Icons.star : Icons.star_border),
            color: item.isFavorite ? AppColors.warning : null,
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Disponible próximamente')),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: item.type.color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.type.icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.title, style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20)),
                      Text(item.category ?? item.type.label, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (item.username case final username?)
              ItemFieldCard(
                label: 'Usuario',
                child: Text(username, style: theme.textTheme.bodyLarge),
                onCopy: () => _copyToClipboard('Usuario', username),
              ),
            if (item.password case final password?) ...[
              const SizedBox(height: 14),
              ItemPasswordFieldCard(
                password: password,
                onCopy: () => _copyToClipboard('Contraseña', password),
              ),
            ],
            if (item.url case final url?) ...[
              const SizedBox(height: 14),
              ItemFieldCard(
                label: 'Sitio web',
                icon: Icons.language,
                child: Text(
                  url,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            ],
            if (item.notes case final notes?) ...[
              const SizedBox(height: 14),
              ItemFieldCard(label: 'Notas', child: Text(notes, style: theme.textTheme.bodyLarge)),
            ],
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 14),
              ItemFieldCard(
                label: 'Etiquetas',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in item.tags) Chip(label: Text(tag)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _confirmDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
