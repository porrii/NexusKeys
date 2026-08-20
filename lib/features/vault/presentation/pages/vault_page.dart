import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/vault_item_tile.dart';

enum _VaultFilter { all, favorites, recent }

/// Reproduces img/03_vault.png.
///
/// The item list below uses sample data — step 9 ("Implementar CRUD
/// completo de la bóveda") replaces it with real rows read from
/// [VaultSession.database]. This module only builds the screen's visual
/// shell: search field, category chips, list layout, FAB and bottom nav.
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
  _VaultFilter _filter = _VaultFilter.all;

  static const _sampleItems = [
    (title: 'Google', subtitle: 'ivan@gmail.com', color: Color(0xFF1E88E5), favorite: true),
    (title: 'GitHub', subtitle: 'ivan_dev', color: Color(0xFF24292E), favorite: false),
    (title: 'YouTube', subtitle: 'ivan@gmail.com', color: Color(0xFFE53935), favorite: false),
    (title: 'Netflix', subtitle: 'ivan@gmail.com', color: Color(0xFFB71C1C), favorite: false),
    (
      title: 'Tarjeta Banco',
      subtitle: '•••• •••• •••• 1234',
      color: Color(0xFF1565C0),
      favorite: false,
    ),
    (
      title: 'Correo Pro',
      subtitle: 'ivan@protonmail.com',
      color: Color(0xFF5E35B1),
      favorite: false,
    ),
  ];

  List<({String title, String subtitle, Color color, bool favorite})> get _visibleItems {
    return switch (_filter) {
      _VaultFilter.all => _sampleItems,
      _VaultFilter.favorites => _sampleItems.where((i) => i.favorite).toList(),
      _VaultFilter.recent => _sampleItems,
    };
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disponible próximamente')),
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
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              itemCount: _visibleItems.length,
              itemBuilder: (context, index) {
                final item = _visibleItems[index];
                return VaultItemTile(
                  title: item.title,
                  subtitle: item.subtitle,
                  avatarColor: item.color,
                  isFavorite: item.favorite,
                  onTap: _showComingSoon,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showComingSoon,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: _VaultBottomNav(onNonVaultTap: _showComingSoon),
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
  const _VaultBottomNav({required this.onNonVaultTap});

  final VoidCallback onNonVaultTap;

  static const _vaultTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: _vaultTabIndex,
      onDestinationSelected: (index) {
        if (index != _vaultTabIndex) onNonVaultTap();
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.lock_outlined), selectedIcon: Icon(Icons.lock), label: 'Bóveda'),
        NavigationDestination(icon: Icon(Icons.speed_outlined), label: 'Generador'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
      ],
    );
  }
}
