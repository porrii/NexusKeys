import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../vault/domain/entities/vault_item_type.dart';
import '../../../vault/domain/repositories/vault_repository.dart';

/// "Etiquetas" — every distinct tag currently used across the vault, with
/// how many items carry it. Unlike categories (img/11_categories.png,
/// CategoriesPage), tags have no separate managed list to create ahead of
/// time: a tag only exists because at least one item's [VaultItem.tags]
/// carries it, so this page is read-only, computed straight from
/// [VaultRepository.currentItems].
///
/// No reference mockup shows this as its own phone-sized screen — it only
/// appears as a sidebar destination in img/13_tablet.png and
/// img/14_windows.png. This gives it a real place to live on mobile first,
/// styled consistently with CategoriesPage, ahead of the wide-screen
/// layout that will surface it directly in that sidebar.
class TagsPage extends StatelessWidget {
  const TagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vault = sl<VaultRepository>();
    final counts = <String, int>{};
    for (final item in vault.currentItems) {
      for (final tag in item.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
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
                  );
                },
              ),
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.color, required this.label, required this.count});

  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          ],
        ),
      ),
    );
  }
}
