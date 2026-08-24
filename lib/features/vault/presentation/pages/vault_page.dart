import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/vault_item.dart';
import '../../domain/repositories/vault_repository.dart';
import '../../../backup/presentation/pages/import_export_page.dart';
import '../../../generator/presentation/pages/generator_page.dart';
import '../../../settings/presentation/pages/categories_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../settings/presentation/pages/tags_page.dart';
import '../../../settings/presentation/pages/trash_page.dart';
import '../widgets/vault_detail_pane.dart';
import '../widgets/vault_item_tile.dart';
import '../widgets/vault_sidebar.dart';
import 'edit_vault_item_page.dart';
import 'item_details_page.dart';

enum _VaultFilter { all, favorites, recent }

/// Below this width, VaultPage keeps its mobile Scaffold (drawer, bottom
/// nav, filter chips, pushed detail page) exactly as before. At or above
/// it, img/13_tablet.png and img/14_windows.png's persistent sidebar +
/// list + inline detail layout takes over instead.
const double kVaultWideBreakpoint = 700;

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
  final _searchController = TextEditingController();
  _VaultFilter _filter = _VaultFilter.all;
  bool _isSearching = false;
  String _searchQuery = '';

  // Wide-layout only (see kVaultWideBreakpoint) — mobile never touches
  // these, since it pushes ItemDetailsPage as a route instead of keeping a
  // selection inline.
  VaultSidebarSection _sidebarSection = VaultSidebarSection.vault;
  int? _selectedItemId;

  // Mobile-layout only: Bóveda/Generador/Ajustes each get their own nested
  // Navigator so pushing within one (item details, an edit form, a
  // settings sub-page, ...) only covers that tab's content — the outer
  // Scaffold's bottomNavigationBar, built once around all three, is never
  // part of any of their route stacks and so never disappears.
  int _bottomNavIndex = 0;
  final _vaultTabNavigatorKey = GlobalKey<NavigatorState>();
  final _generatorTabNavigatorKey = GlobalKey<NavigatorState>();
  final _settingsTabNavigatorKey = GlobalKey<NavigatorState>();

  List<GlobalKey<NavigatorState>> get _tabNavigatorKeys =>
      [_vaultTabNavigatorKey, _generatorTabNavigatorKey, _settingsTabNavigatorKey];

  /// IndexedStack builds every child eagerly, every time — without this,
  /// switching to Bóveda would also construct GeneratorPage and
  /// SettingsPage (and touch every service they resolve via GetIt)
  /// up front, whether or not the user ever visits those tabs. Once a tab
  /// has been visited, its slot keeps rendering the real Navigator from
  /// then on instead of reverting to the placeholder, so its state and
  /// route stack survive being switched away from.
  final Set<int> _visitedTabIndices = {0};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<VaultItem> _applyFilter(List<VaultItem> items) {
    return switch (_filter) {
      _VaultFilter.all => items,
      _VaultFilter.favorites => items.where((i) => i.isFavorite).toList(),
      // Already sorted by most-recently-updated by the repository.
      _VaultFilter.recent => items,
    };
  }

  /// Matches against every field a user is likely to search by — not just
  /// the title shown in the row — so e.g. searching an email finds the
  /// account it belongs to even if the title doesn't mention it.
  List<VaultItem> _applySearch(List<VaultItem> items) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return items;

    return items.where((item) {
      final haystack = [
        item.title,
        item.username ?? '',
        item.url ?? '',
        item.category ?? '',
        ...item.tags,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  void _enterSearch() => setState(() => _isSearching = true);

  void _exitSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  /// Kept for the wide layout's sidebar, which still pushes Ajustes over
  /// itself (see VaultSidebar's doc comment) — mobile's Ajustes is a
  /// persistent tab instead, so it never calls this.
  void _openSettings(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
  }

  void _openCreateItem(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditVaultItemPage(onSave: _repository.create),
      ),
    );
  }

  /// [context] determines which Navigator the push (and any further pushes
  /// — edit, and the delete-undo SnackBar's Scaffold) lands on: the caller
  /// passes whatever context is a descendant of the Navigator it wants
  /// covered — Bóveda's own nested one on mobile, the shared outer one on
  /// the wide layout.
  void _openItemDetails(BuildContext context, VaultItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemDetailsPage(
          item: item,
          onToggleFavorite: (value) {
            final id = item.id;
            if (id != null) _repository.setFavorite(id, value);
          },
          onEdit: () => _openEditAndReturn(context, item),
          onDelete: () {
            _deleteWithUndo(context, item);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<VaultItem?> _openEditAndReturn(BuildContext context, VaultItem item) {
    return Navigator.of(context).push<VaultItem>(
      MaterialPageRoute(
        builder: (_) => EditVaultItemPage(existingItem: item, onSave: _repository.update),
      ),
    );
  }

  void _deleteWithUndo(BuildContext context, VaultItem item) {
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

  VaultItem? _resolveSelected(List<VaultItem> items) {
    final id = _selectedItemId;
    if (id == null) return null;
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _onSidebarSelect(BuildContext context, VaultSidebarSection section) {
    switch (section) {
      case VaultSidebarSection.vault:
        setState(() {
          _sidebarSection = section;
          _filter = _VaultFilter.all;
        });
      case VaultSidebarSection.favorites:
        setState(() {
          _sidebarSection = section;
          _filter = _VaultFilter.favorites;
        });
      case VaultSidebarSection.recent:
        setState(() {
          _sidebarSection = section;
          _filter = _VaultFilter.recent;
        });
      case VaultSidebarSection.categories:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesPage()));
      case VaultSidebarSection.tags:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TagsPage()));
      case VaultSidebarSection.trash:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrashPage()));
      case VaultSidebarSection.settings:
        _openSettings(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kVaultWideBreakpoint) {
          return _buildWideLayout(context);
        }
        return _buildMobileScaffold(context);
      },
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          VaultSidebar(
            selected: _sidebarSection,
            onSelect: (section) => _onSidebarSelect(context, section),
            onCreateItem: () => _openCreateItem(context),
            onLock: () => widget.onLock?.call(),
          ),
          SizedBox(
            width: 340,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar en la bóveda',
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<VaultItem>>(
                    initialData: _repository.currentItems,
                    stream: _repository.itemsStream,
                    builder: (context, snapshot) {
                      final source = snapshot.data ?? const <VaultItem>[];
                      final items =
                          _searchQuery.trim().isEmpty ? _applyFilter(source) : _applySearch(source);

                      if (items.isEmpty) {
                        return Center(
                          child: Text(
                            _searchQuery.trim().isEmpty ? 'Tu bóveda está vacía' : 'Sin resultados',
                            style: theme.textTheme.bodyMedium,
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return VaultItemTile(
                            title: item.title,
                            subtitle: item.username ?? item.url ?? item.category ?? '',
                            avatarColor: item.type.color,
                            isFavorite: item.isFavorite,
                            onTap: () => setState(() => _selectedItemId = item.id),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: theme.dividerColor),
          Expanded(
            child: StreamBuilder<List<VaultItem>>(
              initialData: _repository.currentItems,
              stream: _repository.itemsStream,
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <VaultItem>[];
                final selected = _resolveSelected(items);
                return VaultDetailPane(
                  item: selected,
                  onToggleFavorite: selected == null
                      ? null
                      : (value) {
                          final id = selected.id;
                          if (id != null) _repository.setFavorite(id, value);
                        },
                  onEdit: selected == null ? null : () => _openEditAndReturn(context, selected),
                  onDelete: selected == null ? null : () => _deleteWithUndo(context, selected),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The persistent shell: one bottomNavigationBar shared by all three
  /// tabs, each with its own nested Navigator (see the GlobalKey fields
  /// above) so none of their internal pushes ever cover it. IndexedStack
  /// keeps every tab's widget subtree — and so its Navigator's route
  /// stack — alive while hidden, rather than tearing it down on switch.
  Widget _buildMobileScaffold(BuildContext context) {
    Widget tabSlot(int index, GlobalKey<NavigatorState> key, WidgetBuilder rootBuilder) {
      if (!_visitedTabIndices.contains(index)) return const SizedBox.shrink();
      return Navigator(key: key, onGenerateRoute: (settings) => MaterialPageRoute(builder: rootBuilder));
    }

    return Scaffold(
      body: IndexedStack(
        index: _bottomNavIndex,
        children: [
          tabSlot(0, _vaultTabNavigatorKey, _buildVaultTabRoot),
          tabSlot(1, _generatorTabNavigatorKey, (_) => const GeneratorPage()),
          tabSlot(2, _settingsTabNavigatorKey, (_) => const SettingsPage()),
        ],
      ),
      bottomNavigationBar: _VaultBottomNav(
        currentIndex: _bottomNavIndex,
        onIndexSelected: (index) {
          if (index == _bottomNavIndex) {
            // Tapping the already-active tab again pops it back to its
            // own root, mirroring how most bottom-nav apps behave.
            _tabNavigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
          } else {
            setState(() {
              _bottomNavIndex = index;
              _visitedTabIndices.add(index);
            });
          }
        },
      ),
    );
  }

  Widget _buildVaultTabRoot(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        automaticallyImplyLeading: !_isSearching,
        titleSpacing: _isSearching ? 4 : null,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Buscar en la bóveda',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          }),
                        ),
                ),
              )
            : Text('NexusKeys', style: theme.textTheme.titleLarge),
        actions: [
          if (_isSearching)
            TextButton(onPressed: _exitSearch, child: const Text('Cancelar'))
          else
            IconButton(icon: const Icon(Icons.search), onPressed: _enterSearch),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.lock_outlined),
                title: const Text('Bloquear bóveda'),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onLock?.call();
                },
              ),
              ListTile(
                leading: const Icon(Icons.import_export_outlined),
                title: const Text('Importar / Exportar'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ImportExportPage(
                        onImportComplete: () {
                          // A restore just replaced the auth header this
                          // session was unlocked with, so every pushed
                          // route (this one, VaultPage) has to go — only
                          // AuthGatePage's own re-check of isVaultInitialized
                          // is valid now, and it needs to be visible, not
                          // buried under routes for a vault that's gone.
                          Navigator.of(context).popUntil((route) => route.isFirst);
                          widget.onLock?.call();
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: StreamBuilder<List<VaultItem>>(
                  initialData: _repository.currentItems,
                  stream: _repository.itemsStream,
                  builder: (context, snapshot) {
                    final count = _applySearch(snapshot.data ?? const []).length;
                    return Text('Resultados ($count)', style: theme.textTheme.bodyMedium);
                  },
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                readOnly: true,
                onTap: _enterSearch,
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
          ],
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<VaultItem>>(
              initialData: _repository.currentItems,
              stream: _repository.itemsStream,
              builder: (context, snapshot) {
                final source = snapshot.data ?? const <VaultItem>[];
                final items = _isSearching ? _applySearch(source) : _applyFilter(source);

                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      _isSearching ? 'Sin resultados' : 'Tu bóveda está vacía',
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
                      alwaysShowStar: _isSearching,
                      onTap: () => _openItemDetails(context, item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _isSearching
          ? null
          : FloatingActionButton(
              onPressed: () => _openCreateItem(context),
              child: const Icon(Icons.add),
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
  const _VaultBottomNav({required this.currentIndex, required this.onIndexSelected});

  final int currentIndex;
  final ValueChanged<int> onIndexSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onIndexSelected,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.lock_outlined), selectedIcon: Icon(Icons.lock), label: 'Bóveda'),
        NavigationDestination(icon: Icon(Icons.speed_outlined), label: 'Generador'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
      ],
    );
  }
}
