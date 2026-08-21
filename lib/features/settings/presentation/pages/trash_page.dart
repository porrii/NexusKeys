import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../vault/domain/entities/vault_item.dart';
import '../../../vault/domain/repositories/vault_repository.dart';

/// "Papelera" from img/08_settings.png — no mockup of its own. Every item
/// here was soft-deleted via [VaultRepository.moveToTrash]; this is where
/// that trash actually becomes reachable again (restore) or final
/// (eliminar permanentemente), rather than sitting inaccessible forever.
class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final VaultRepository _repository = sl<VaultRepository>();

  Future<void> _confirmPermanentDelete(VaultItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar definitivamente?'),
        content: Text('"${item.title}" no podrá recuperarse.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed == true) {
      final id = item.id;
      if (id != null) await _repository.deletePermanently(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Papelera')),
      body: SafeArea(
        child: StreamBuilder<List<VaultItem>>(
          initialData: _repository.currentTrash,
          stream: _repository.trashStream,
          builder: (context, snapshot) {
            final items = snapshot.data ?? const [];

            if (items.isEmpty) {
              return Center(
                child: Text('La papelera está vacía', style: theme.textTheme.bodyMedium),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.title,
                                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(item.type.label, style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.restore_outlined),
                          tooltip: 'Restaurar',
                          onPressed: () {
                            final id = item.id;
                            if (id != null) _repository.restoreFromTrash(id);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_forever_outlined),
                          tooltip: 'Eliminar definitivamente',
                          onPressed: () => _confirmPermanentDelete(item),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
