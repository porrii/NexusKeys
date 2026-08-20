import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/widgets/app_password_field.dart';
import '../../../generator/domain/entities/generator_options.dart';
import '../../../generator/domain/services/password_generator_service.dart';
import '../../domain/entities/vault_item.dart';
import '../../domain/entities/vault_item_type.dart';

/// Create/edit form for a vault item — reproduces img/05_new_item.png for
/// creation; there's no separate mockup for editing, so it reuses the same
/// layout pre-filled, titled "Editar elemento". Deletion isn't reachable
/// from here — img/04_item_details.png's "Eliminar" button is the only
/// place that lives.
class EditVaultItemPage extends StatefulWidget {
  const EditVaultItemPage({super.key, this.existingItem, this.onSave});

  /// Null when creating a new item; the item being edited otherwise.
  final VaultItem? existingItem;

  final ValueChanged<VaultItem>? onSave;

  @override
  State<EditVaultItemPage> createState() => _EditVaultItemPageState();
}

class _EditVaultItemPageState extends State<EditVaultItemPage> {
  final PasswordGeneratorService _generator = sl<PasswordGeneratorService>();

  late VaultItemType _type;
  late final TextEditingController _title;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _url;
  late final TextEditingController _notes;
  late final TextEditingController _folder;
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
    _folder = TextEditingController(text: item?.category ?? '');
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
    _folder.dispose();
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
      category: _folder.text.trim().isEmpty ? null : _folder.text.trim(),
      tags: tags,
      color: existing?.color,
      icon: existing?.icon,
      isFavorite: _isFavorite,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    widget.onSave?.call(item);
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar elemento' : 'Nuevo elemento'),
        actions: [
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
              decoration: InputDecoration(
                labelText: 'Título',
                hintText: 'Ej. Spotify',
                errorText: _titleError,
              ),
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Usuario', hintText: 'Ej. usuario@email.com'),
            ),
            const SizedBox(height: 16),
            AppPasswordField(
              controller: _password,
              hintText: 'Generar contraseña',
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Generar contraseña',
                onPressed: () => setState(
                  () => _password.text = _generator.generate(GeneratorOptions.recommended()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _url,
              decoration: const InputDecoration(labelText: 'Sitio web', hintText: 'https://ejemplo.com'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _folder,
              decoration: const InputDecoration(labelText: 'Carpeta', hintText: 'Sin carpeta'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tags,
              decoration: const InputDecoration(
                labelText: 'Etiquetas',
                hintText: 'Seleccionar etiquetas',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notas', hintText: 'Notas adicionales'),
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
