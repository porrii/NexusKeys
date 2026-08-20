import 'package:flutter/material.dart';

import '../../../../core/widgets/app_password_field.dart';
import '../../domain/entities/vault_item.dart';
import '../../domain/entities/vault_item_type.dart';

/// Create/edit form for a vault item.
///
/// No reference mockup covers this exact state either way — img/05_new_item.png
/// is its own later module with per-type fields — so this deliberately stays
/// generic (the fields every item type shares) rather than guessing at a
/// design. It exists now so step 9's CRUD is actually reachable from the UI,
/// not just exercised by repository tests.
class EditVaultItemPage extends StatefulWidget {
  const EditVaultItemPage({super.key, this.existingItem, this.onSave, this.onDelete});

  /// Null when creating a new item; the item being edited otherwise.
  final VaultItem? existingItem;

  final ValueChanged<VaultItem>? onSave;

  /// Only ever called when [existingItem] is non-null — there's nothing to
  /// delete while creating a new item.
  final VoidCallback? onDelete;

  @override
  State<EditVaultItemPage> createState() => _EditVaultItemPageState();
}

class _EditVaultItemPageState extends State<EditVaultItemPage> {
  late VaultItemType _type;
  late final TextEditingController _title;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _url;
  late final TextEditingController _notes;
  late final TextEditingController _category;
  late final TextEditingController _tags;
  late bool _isFavorite;
  String? _titleError;

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _type = item?.type ?? VaultItemType.password;
    _title = TextEditingController(text: item?.title ?? '');
    _username = TextEditingController(text: item?.username ?? '');
    _password = TextEditingController(text: item?.password ?? '');
    _url = TextEditingController(text: item?.url ?? '');
    _notes = TextEditingController(text: item?.notes ?? '');
    _category = TextEditingController(text: item?.category ?? '');
    _tags = TextEditingController(text: item?.tags.join(', ') ?? '');
    _isFavorite = item?.isFavorite ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _username.dispose();
    _password.dispose();
    _url.dispose();
    _notes.dispose();
    _category.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'El título es obligatorio');
      return;
    }

    final now = DateTime.now();
    final existing = widget.existingItem;
    final tags = _tags.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

    final item = VaultItem(
      id: existing?.id,
      type: _type,
      title: title,
      username: _username.text.trim().isEmpty ? null : _username.text.trim(),
      password: _password.text.isEmpty ? null : _password.text,
      url: _url.text.trim().isEmpty ? null : _url.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      category: _category.text.trim().isEmpty ? null : _category.text.trim(),
      tags: tags,
      color: existing?.color,
      icon: existing?.icon,
      isFavorite: _isFavorite,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    widget.onSave?.call(item);
    Navigator.of(context).pop();
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
    if (confirmed != true || !mounted) return;
    widget.onDelete?.call();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar elemento' : 'Nuevo elemento'),
        actions: [
          if (_isEditing)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _confirmDelete),
          IconButton(icon: const Icon(Icons.check), onPressed: _submit),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<VaultItemType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final type in VaultItemType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: !_isEditing,
              decoration: InputDecoration(labelText: 'Título', errorText: _titleError),
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Usuario'),
            ),
            const SizedBox(height: 16),
            AppPasswordField(controller: _password, hintText: 'Contraseña'),
            const SizedBox(height: 16),
            TextField(
              controller: _url,
              decoration: const InputDecoration(labelText: 'Sitio web'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tags,
              decoration: const InputDecoration(labelText: 'Etiquetas (separadas por comas)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notas'),
              maxLines: 4,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Favorito'),
              value: _isFavorite,
              onChanged: (value) => setState(() => _isFavorite = value),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(_isEditing ? 'Guardar cambios' : 'Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
