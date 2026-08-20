import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/vault_item.dart';
import '../../domain/repositories/vault_repository.dart';
import '../../../generator/presentation/pages/generator_page.dart';
import '../widgets/vault_item_tile.dart';
import 'edit_vault_item_page.dart';
import 'item_details_page.dart';

enum _VaultFilter { all, favorites, recent }

/// Reproduces img/03_vault.png, backed by the real encrypted database.
class VaultPage extends StatefulWidget {
  const VaultPage({super.key, this.onLock});

  /// No reference mockup shows a drawer, but a hamburger icon that does
  /// nothing would be worse than not having one — this is the one entry
  /// it opens with for now, since locking the vault manually is a real
  /// requirement and not just a placeholder. The full drawer/settings menu
  /// belongs to the Ajustes module (img/08_settings.png).
  final VoidCallback? onLock;

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  final VaultRepository _repository = sl<VaultRepository>();
  _VaultFilter _filter = _VaultFilter.all;

  List<VaultItem> _applyFilter(List<VaultItem> items) {
    return switch (_filter) {
      _VaultFilter.all => items,
      _VaultFilter.favorites => items.where((i) => i.isFavorite).toList(),
      // Already sorted by most-recently-updated by the repository.
      _VaultFilter.recent => items,
    };
  }

  void _openGenerator() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GeneratorPage()));
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disponible próximamente')),
    );
  }

  void _openCreateItem() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditVaultItemPage(onSave: _repository.create),
      ),
    );
  }

  void _openItemDetails(VaultItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemDetailsPage(
          item: item,
          onToggleFavorite: (value) {
            final id = item.id;
            if (id != null) _repository.setFavorite(id, value);
          },
          onEdit: () => _openEditAndReturn(item),
          onDelete: () {
            _deleteWithUndo(item);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<VaultItem?> _openEditAndReturn(VaultItem item) {
    return Navigator.of(context).push<VaultItem>(
      MaterialPageRoute(
        builder: (_) => EditVaultItemPage(existingItem: item, onSave: _repository.update),
      ),
    );
  }

  void _deleteWithUndo(VaultItem item) {
    final id = item.id;
    if (id == null) return;
    _repository.moveToTrash(id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${item.title}" se movió a la papelera'),
        action: SnackBarAction(label: 'Deshacer', onPressed: () => _repository.restoreFromTrash(id)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text('NexusKeys', style: theme.textTheme.titleLarge),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _showComingSoon),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListTile(
            leading: const Icon(Icons.lock_outlined),
            title: const Text('Bloquear bóveda'),
            onTap: () {
              Navigator.of(context).pop();
              widget.onLock?.call();
            },
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              readOnly: true,
              onTap: _showComingSoon,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar en la bóveda',
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'Todas',
                  selected: _filter == _VaultFilter.all,
                  onTap: () => setState(() => _filter = _VaultFilter.all),
                ),
                const SizedBox(width: 10),
                _FilterChip(
                  label: 'Favoritos',
                  selected: _filter == _VaultFilter.favorites,
                  onTap: () => setState(() => _filter = _VaultFilter.favorites),
                ),
                const SizedBox(width: 10),
                _FilterChip(
                  label: 'Recientes',
                  selected: _filter == _VaultFilter.recent,
                  onTap: () => setState(() => _filter = _VaultFilter.recent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<VaultItem>>(
              initialData: _repository.currentItems,
              stream: _repository.itemsStream,
              builder: (context, snapshot) {
                final items = _applyFilter(snapshot.data ?? const []);

                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'Tu bóveda está vacía',
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return VaultItemTile(
                      title: item.title,
                      subtitle: item.username ?? item.url ?? item.category ?? '',
                      avatarColor: item.type.color,
                      isFavorite: item.isFavorite,
                      onTap: () => _openItemDetails(item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateItem,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: _VaultBottomNav(
        onGeneratorTap: _openGenerator,
        onSettingsTap: _showComingSoon,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      backgroundColor: theme.colorScheme.surface,
      selectedColor: AppColors.primary,
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: selected ? Colors.white : theme.textTheme.bodyLarge?.color,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: selected ? AppColors.primary : theme.dividerColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _VaultBottomNav extends StatelessWidget {
  const _VaultBottomNav({required this.onGeneratorTap, required this.onSettingsTap});

  final VoidCallback onGeneratorTap;
  final VoidCallback onSettingsTap;

  static const _vaultTabIndex = 0;
  static const _generatorTabIndex = 1;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: _vaultTabIndex,
      onDestinationSelected: (index) {
        if (index == _generatorTabIndex) {
          onGeneratorTap();
        } else if (index != _vaultTabIndex) {
          onSettingsTap();
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.lock_outlined), selectedIcon: Icon(Icons.lock), label: 'Bóveda'),
        NavigationDestination(icon: Icon(Icons.speed_outlined), label: 'Generador'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
      ],
    );
  }
}
