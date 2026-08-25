import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/vault_item.dart';
import 'item_field_card.dart';

/// The right-hand pane on wide layouts (img/13_tablet.png,
/// img/14_windows.png) — the same fields [ItemDetailsPage] shows on
/// mobile, laid out inline instead of behind its own Scaffold/AppBar, so
/// the sidebar and item list stay visible while browsing details.
class VaultDetailPane extends StatelessWidget {
  const VaultDetailPane({
    required this.item,
    this.onToggleFavorite,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  /// Null shows an empty placeholder — nothing selected yet, or the
  /// selected item just left the list (e.g. moved to the trash).
  final VaultItem? item;

  final ValueChanged<bool>? onToggleFavorite;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  void _copyToClipboard(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copiado')));
  }

  Future<void> _openUrl(BuildContext context, String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.contains('://') ? rawUrl : 'https://$rawUrl');
    if (uri == null || !await canLaunchUrl(uri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace')),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _confirmDelete(BuildContext context) async {
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
    if (confirmed == true) onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = this.item;

    if (item == null) {
      return Center(
        child: Text('Selecciona un elemento', style: theme.textTheme.bodyMedium),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: item.type.color, borderRadius: BorderRadius.circular(14)),
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
            IconButton(
              icon: Icon(item.isFavorite ? Icons.star : Icons.star_border),
              color: item.isFavorite ? AppColors.warning : null,
              onPressed: onToggleFavorite == null ? null : () => onToggleFavorite!(!item.isFavorite),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (item.username case final username?)
          ItemFieldCard(
            label: 'Usuario',
            child: Text(username, style: theme.textTheme.bodyLarge),
            onCopy: () => _copyToClipboard(context, 'Usuario', username),
          ),
        if (item.password case final password?) ...[
          const SizedBox(height: 14),
          ItemPasswordFieldCard(
            password: password,
            onCopy: () => _copyToClipboard(context, 'Contraseña', password),
          ),
        ],
        if (item.url case final url?) ...[
          const SizedBox(height: 14),
          ItemFieldCard(
            label: 'Sitio web',
            icon: Icons.language,
            child: InkWell(
              onTap: () => _openUrl(context, url),
              child: Text(
                url,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
        ...buildExtraDataFields(
          context: context,
          item: item,
          onCopy: (label, value) => _copyToClipboard(context, label, value),
        ),
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
              children: [for (final tag in item.tags) Chip(label: Text(tag))],
            ),
          ),
        ],
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(context),
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
    );
  }
}
