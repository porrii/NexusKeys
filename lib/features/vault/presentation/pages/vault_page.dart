import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/vault_item.dart';
import '../../domain/repositories/vault_repository.dart';
import '../../../generator/presentation/pages/generator_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../settings/presentation/pages/tags_page.dart';
import '../../../settings/presentation/pages/trash_page.dart';
import '../widgets/vault_detail_pane.dart';
import '../widgets/vault_item_tile.dart';
import '../widgets/vault_sidebar.dart';
import 'edit_vault_item_page.dart';
import 'item_details_page.dart';

enum _VaultFilter { all, favorites, recent }

/// Por debajo de este ancho, VaultPage mantiene su Scaffold de móvil
/// (drawer, navegación inferior, chips de filtro, página de detalle
/// empujada) tal cual. A partir de ese ancho, toma el relevo el layout
/// persistente de barra lateral + lista + detalle en línea de
/// img/13_tablet.png e img/14_windows.png.
const double kVaultWideBreakpoint = 700;

/// Reproduce img/03_vault.png, respaldado por la base de datos cifrada
/// real.
class VaultPage extends StatefulWidget {
  const VaultPage({super.key, this.onLock, this.onVaultDeleted});

  /// El icono de candado del AppBar (móvil) y el control de bloqueo de la
  /// barra lateral (layout ancho) llaman a esto directamente — sin
  /// confirmación, igual que funciona un botón físico de bloqueo en otras
  /// partes de la app.
  final VoidCallback? onLock;

  /// El "Eliminar bóveda permanentemente" de Ajustes llama a esto una vez
  /// la bóveda ya no está, para que AuthGatePage pueda volver a la
  /// pantalla de bienvenida en vez de a una pantalla de bloqueo sin nada
  /// que desbloquear.
  final VoidCallback? onVaultDeleted;

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  final VaultRepository _repository = sl<VaultRepository>();
  final _searchController = TextEditingController();
  _VaultFilter _filter = _VaultFilter.all;
  bool _isSearching = false;
  String _searchQuery = '';

  // Solo layout ancho (ver kVaultWideBreakpoint) — el móvil nunca toca
  // esto, ya que empuja ItemDetailsPage como una ruta en vez de mantener
  // una selección en línea.
  VaultSidebarSection _sidebarSection = VaultSidebarSection.vault;
  int? _selectedItemId;

  // Solo layout de móvil: Bóveda/Generador/Ajustes tienen cada uno su
  // propio Navigator anidado para que empujar dentro de uno (detalle de un
  // elemento, un formulario de edición, una subpágina de ajustes, ...)
  // solo tape el contenido de esa pestaña — la bottomNavigationBar del
  // Scaffold exterior, construida una vez alrededor de las tres, nunca es
  // parte de ninguna de sus pilas de rutas y por eso nunca desaparece.
  int _bottomNavIndex = 0;
  final _vaultTabNavigatorKey = GlobalKey<NavigatorState>();
  final _generatorTabNavigatorKey = GlobalKey<NavigatorState>();
  final _settingsTabNavigatorKey = GlobalKey<NavigatorState>();

  List<GlobalKey<NavigatorState>> get _tabNavigatorKeys =>
      [_vaultTabNavigatorKey, _generatorTabNavigatorKey, _settingsTabNavigatorKey];

  /// IndexedStack construye todos sus hijos de forma anticipada, siempre —
  /// sin esto, cambiar a Bóveda también construiría GeneratorPage y
  /// SettingsPage (y tocaría todos los servicios que resuelven vía GetIt)
  /// de entrada, visite o no el usuario esas pestañas. Una vez visitada una
  /// pestaña, su hueco sigue renderizando el Navigator real a partir de
  /// entonces en vez de volver al placeholder, así que su estado y su pila
  /// de rutas sobreviven a que se cambie de pestaña.
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
      // El repositorio ya los ordena por actualizado más reciente.
      _VaultFilter.recent => items,
    };
  }

  /// Casa contra todos los campos por los que es probable que un usuario
  /// busque — no solo el título que se ve en la fila — para que, p. ej.,
  /// buscar un email encuentre la cuenta a la que pertenece aunque el
  /// título no lo mencione.
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
        ...item.extraData.values,
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

  void _openCreateItem(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditVaultItemPage(onSave: _repository.create),
      ),
    );
  }

  /// [context] determina en qué Navigator cae el push (y cualquier push
  /// posterior — editar, y el Scaffold del SnackBar de deshacer-borrado):
  /// quien llama pasa el context que sea descendiente del Navigator que
  /// quiere que se tape — el anidado propio de Bóveda en móvil, el exterior
  /// compartido en el layout ancho.
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

  /// Cada cambio de sección descarta lo que estuviera seleccionado en la
  /// anterior — si no, el panel de detalle podría seguir mostrando un
  /// elemento de Bóveda tras cambiar a Favoritos, aunque no se haya
  /// pulsado nada en Favoritos de verdad. Etiquetas/Papelera/Ajustes no
  /// usan `_selectedItemId` ellas mismas, pero limpiarlo aquí también
  /// significa que ya está reseteado si el usuario vuelve luego a
  /// Bóveda/Favoritos/Recientes.
  void _onSidebarSelect(BuildContext context, VaultSidebarSection section) {
    setState(() {
      _sidebarSection = section;
      _selectedItemId = null;
      _filter = switch (section) {
        VaultSidebarSection.favorites => _VaultFilter.favorites,
        VaultSidebarSection.recent => _VaultFilter.recent,
        _ => _VaultFilter.all,
      };
    });
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

  /// La barra lateral se queda visible se elija la sección que se elija —
  /// cada sección se renderiza en línea en el área de contenido de al
  /// lado, en vez de que Etiqueta/Papelera/Ajustes empujen una ruta que
  /// tapa la barra lateral como hacían antes. Solo la navegación *desde
  /// dentro* de una de esas secciones (p. ej. la subpágina "Tema" de
  /// Ajustes) sigue empujándose sobre la barra lateral; este cambio de
  /// primer nivel nunca lo hace.
  Widget _buildWideLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          VaultSidebar(
            selected: _sidebarSection,
            onSelect: (section) => _onSidebarSelect(context, section),
            onCreateItem: () => _openCreateItem(context),
            onLock: () => widget.onLock?.call(),
          ),
          Expanded(child: _buildWideContent(context)),
        ],
      ),
    );
  }

  Widget _buildWideContent(BuildContext context) {
    switch (_sidebarSection) {
      case VaultSidebarSection.vault:
      case VaultSidebarSection.favorites:
      case VaultSidebarSection.recent:
        return _buildVaultSplitView(context);
      case VaultSidebarSection.tags:
        return const TagsPage(embedded: true);
      case VaultSidebarSection.trash:
        return const TrashPage(embedded: true);
      case VaultSidebarSection.settings:
        return SettingsPage(
          embedded: true,
          onLock: widget.onLock,
          onVaultDeleted: widget.onVaultDeleted,
        );
    }
  }

  /// La división compartida lista+detalle de Bóveda/Favoritos/Recientes —
  /// el panel de lista central persistente y el panel de detalle en línea a
  /// la derecha de img/13_tablet.png e img/14_windows.png.
  Widget _buildVaultSplitView(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
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
                          subtitle: item.subtitleHint,
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
    );
  }

  /// La envoltura persistente: una bottomNavigationBar compartida por las
  /// tres pestañas, cada una con su propio Navigator anidado (ver los
  /// campos GlobalKey de arriba) para que ninguno de sus pushes internos la
  /// tape nunca. IndexedStack mantiene vivo el subárbol de widgets de cada
  /// pestaña — y por tanto la pila de rutas de su Navigator — mientras está
  /// oculta, en vez de destruirlo al cambiar.
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
          tabSlot(2, _settingsTabNavigatorKey, (_) => SettingsPage(onLock: widget.onLock, onVaultDeleted: widget.onVaultDeleted)),
        ],
      ),
      bottomNavigationBar: _VaultBottomNav(
        currentIndex: _bottomNavIndex,
        onIndexSelected: (index) {
          if (index == _bottomNavIndex) {
            // Pulsar otra vez la pestaña ya activa la devuelve a su propia
            // raíz, como se comportan la mayoría de apps con navegación
            // inferior.
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
        automaticallyImplyLeading: false,
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
          else ...[
            IconButton(icon: const Icon(Icons.search), onPressed: _enterSearch),
            IconButton(
              icon: const Icon(Icons.lock_outlined),
              tooltip: 'Bloquear bóveda',
              onPressed: () => widget.onLock?.call(),
            ),
          ],
        ],
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
                      subtitle: item.subtitleHint,
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
