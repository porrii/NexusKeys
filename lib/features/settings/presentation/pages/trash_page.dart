import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/widgets/embedded_section_header.dart';
import '../../../vault/domain/entities/vault_item.dart';
import '../../../vault/domain/repositories/vault_repository.dart';

/// "Papelera" de img/08_settings.png — sin mockup propio. Cada elemento de
/// aquí se borró de forma suave con [VaultRepository.moveToTrash]; este es
/// el sitio donde esa papelera vuelve a ser alcanzable (restaurar) o
/// definitiva (eliminar permanentemente), en vez de quedarse inaccesible
/// para siempre.
class TrashPage extends StatefulWidget {
  const TrashPage({super.key, this.embedded = false});

  /// True en los layouts anchos (img/13_tablet.png, img/14_windows.png),
  /// donde esto se renderiza en línea junto a la barra lateral en vez de
  /// tras su propio Scaffold/AppBar al que se llega empujando una ruta
  /// sobre todo lo demás.
  final bool embedded;

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

    final body = SafeArea(
      top: !widget.embedded,
      child: Column(
        children: [
          if (widget.embedded) const EmbeddedSectionHeader('Papelera'),
          Expanded(
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
        ],
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Papelera')), body: body);
  }
}
