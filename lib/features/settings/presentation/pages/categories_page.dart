import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../vault/domain/entities/vault_item_type.dart';
import '../../../vault/domain/repositories/category_repository.dart';
import '../../../vault/domain/repositories/vault_repository.dart';

/// "Gestionar categorías" — reproduces img/11_categories.png.
///
/// A category here is a managed name (see [CategoryRepository]) kept
/// separate from [VaultItem.category], the plain freeform string every item
/// actually carries — that's what its row's count is computed from, so a
/// category can exist (and show "0") before any item is filed under it, and
/// an item can carry a category name that isn't managed here at all.
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final CategoryRepository _categories = sl<CategoryRepository>();
  final VaultRepository _vault = sl<VaultRepository>();

  int _countFor(String name) =>
      _vault.currentItems.where((item) => item.category == name).length;

  Future<void> _createCategory() async {
    final name = await _promptForName();
    if (name == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    try {
      await _categories.create(trimmed);
      if (mounted) setState(() {});
    } on ArgumentError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya existe una categoría con ese nombre.')),
      );
    }
  }

  Future<String?> _promptForName() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre de la categoría'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories.currentCategories;

    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                children: [
                  _CategoryRow(
                    icon: Icons.apps,
                    color: AppColors.primary,
                    label: 'Todas',
                    count: _vault.currentItems.length,
                  ),
                  for (var i = 0; i < categories.length; i++)
                    _CategoryRow(
                      icon: Icons.folder_outlined,
                      color: VaultItemType.values[i % VaultItemType.values.length].color,
                      label: categories[i].name,
                      count: _countFor(categories[i].name),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _createCategory,
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva categoría'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
  });

  final IconData icon;
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
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('$count', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
