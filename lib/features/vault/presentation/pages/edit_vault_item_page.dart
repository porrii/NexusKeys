import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/widgets/app_password_field.dart';
import '../../../generator/domain/entities/generator_options.dart';
import '../../../generator/domain/services/password_generator_service.dart';
import '../../domain/entities/vault_item.dart';
import '../../domain/entities/vault_item_type.dart';
import '../../domain/repositories/vault_repository.dart';

/// Formulario de crear/editar un elemento de la bóveda — reproduce
/// img/05_new_item.png para la creación (los campos del propio mockup son
/// exactamente los de [VaultItemType.password], el único tipo que muestra);
/// no hay un mockup aparte para editar, así que reutiliza el mismo layout
/// pre-rellenado, titulado "Editar elemento". El borrado no es alcanzable
/// desde aquí — el botón "Eliminar" de img/04_item_details.png es el único
/// sitio donde vive.
///
/// Los campos que aparecen bajo "Tipo" cambian con él: cada
/// [VaultItemType] tiene su propio conjunto, genuinamente distinto (una
/// tarjeta pide su número y su CVV, no un usuario) en vez de un formulario
/// genérico idéntico se elija lo que se elija.
class EditVaultItemPage extends StatefulWidget {
  const EditVaultItemPage({super.key, this.existingItem, this.onSave});

  /// Null al crear un elemento nuevo; el elemento que se está editando en
  /// caso contrario.
  final VaultItem? existingItem;

  final ValueChanged<VaultItem>? onSave;

  @override
  State<EditVaultItemPage> createState() => _EditVaultItemPageState();
}

class _EditVaultItemPageState extends State<EditVaultItemPage> {
  final PasswordGeneratorService _generator = sl<PasswordGeneratorService>();
  final VaultRepository _repository = sl<VaultRepository>();

  late VaultItemType _type;
  late final TextEditingController _title;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _url;
  late final TextEditingController _notes;
  late final TextEditingController _folder;
  late final TextEditingController _tags;
  late final TextEditingController _cardholder;
  late final TextEditingController _cardNumber;
  late final TextEditingController _cardExpiry;
  late final TextEditingController _cardCvv;
  late final TextEditingController _fullName;
  late final TextEditingController _documentNumber;
  late final TextEditingController _phone;
  late final TextEditingController _ssid;
  late bool _isFavorite;
  String? _titleError;

  bool get _isEditing => widget.existingItem != null;

  /// Todas las etiquetas distintas ya usadas en la bóveda, para el
  /// autocompletado de Etiquetas — ordenadas para que las sugerencias
  /// aparezcan en un orden estable.
  List<String> get _existingTags {
    final tags = <String>{};
    for (final item in _repository.currentItems) {
      tags.addAll(item.tags);
    }
    final sorted = tags.toList()..sort();
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    final extra = item?.extraData ?? const {};
    _type = item?.type ?? VaultItemType.password;
    _title = TextEditingController(text: item?.title ?? '');
    _username = TextEditingController(text: item?.username ?? '');
    _password = TextEditingController(text: item?.password ?? '');
    _url = TextEditingController(text: item?.url ?? '');
    _notes = TextEditingController(text: item?.notes ?? '');
    _folder = TextEditingController(text: item?.category ?? '');
    _tags = TextEditingController(text: item?.tags.join(', ') ?? '');
    _cardholder = TextEditingController(text: extra[VaultItem.keyCardholder] ?? '');
    _cardNumber = TextEditingController(text: extra[VaultItem.keyCardNumber] ?? '');
    _cardExpiry = TextEditingController(text: extra[VaultItem.keyCardExpiry] ?? '');
    _cardCvv = TextEditingController(text: extra[VaultItem.keyCardCvv] ?? '');
    _fullName = TextEditingController(text: extra[VaultItem.keyFullName] ?? '');
    _documentNumber = TextEditingController(text: extra[VaultItem.keyDocumentNumber] ?? '');
    _phone = TextEditingController(text: extra[VaultItem.keyPhone] ?? '');
    _ssid = TextEditingController(text: extra[VaultItem.keySsid] ?? '');
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
    _cardholder.dispose();
    _cardNumber.dispose();
    _cardExpiry.dispose();
    _cardCvv.dispose();
    _fullName.dispose();
    _documentNumber.dispose();
    _phone.dispose();
    _ssid.dispose();
    super.dispose();
  }

  Map<String, String> _buildExtraData() {
    final entries = <String, String>{};
    void put(String key, TextEditingController controller) {
      final value = controller.text.trim();
      if (value.isNotEmpty) entries[key] = value;
    }

    switch (_type) {
      case VaultItemType.card:
        put(VaultItem.keyCardholder, _cardholder);
        put(VaultItem.keyCardNumber, _cardNumber);
        put(VaultItem.keyCardExpiry, _cardExpiry);
        put(VaultItem.keyCardCvv, _cardCvv);
      case VaultItemType.identity:
        put(VaultItem.keyFullName, _fullName);
        put(VaultItem.keyDocumentNumber, _documentNumber);
        put(VaultItem.keyPhone, _phone);
      case VaultItemType.wifi:
        put(VaultItem.keySsid, _ssid);
      case VaultItemType.password:
      case VaultItemType.secureNote:
        break;
    }
    return entries;
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

    // Solo Contraseña y WiFi usan de verdad username/password/url —
    // limpiarlos para el resto de tipos evita que un cambio de tipo deje
    // datos rancios en campos que su propio formulario ya no muestra.
    final usesLoginFields = _type == VaultItemType.password;
    final usesPasswordField = _type == VaultItemType.password || _type == VaultItemType.wifi;

    final item = VaultItem(
      id: existing?.id,
      type: _type,
      title: title,
      username: usesLoginFields && _username.text.trim().isNotEmpty ? _username.text.trim() : null,
      password: usesPasswordField && _password.text.isNotEmpty ? _password.text : null,
      url: usesLoginFields && _url.text.trim().isNotEmpty ? _url.text.trim() : null,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      category: _folder.text.trim().isEmpty ? null : _folder.text.trim(),
      tags: tags,
      color: existing?.color,
      icon: existing?.icon,
      extraData: _buildExtraData(),
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
            ..._typeSpecificFields(),
            const SizedBox(height: 16),
            TextField(
              controller: _folder,
              decoration: const InputDecoration(labelText: 'Carpeta', hintText: 'Sin carpeta'),
            ),
            const SizedBox(height: 16),
            Autocomplete<String>(
              optionsBuilder: (textEditingValue) {
                // Sugiere etiquetas existentes que no se hayan tecleado ya
                // en el campo separado por comas, casando con lo que haya
                // después de la última coma para que el autocompletado siga
                // funcionando al añadir una segunda o tercera etiqueta.
                final typed = textEditingValue.text;
                final alreadyTyped = typed.split(',').map((t) => t.trim().toLowerCase()).toSet();
                final currentFragment = typed.split(',').last.trim().toLowerCase();
                if (currentFragment.isEmpty) return const [];
                return _existingTags.where(
                  (tag) =>
                      tag.toLowerCase().contains(currentFragment) &&
                      !alreadyTyped.contains(tag.toLowerCase()),
                );
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                // Mantén nuestro propio controller como única fuente de
                // verdad — el interno de Autocomplete aquí solo alimenta el
                // popup de sugerencias, ya que el campo real sigue siendo
                // una cadena separada por comas normal igual que antes.
                controller.text = _tags.text;
                controller.addListener(() {
                  if (controller.text != _tags.text) _tags.text = controller.text;
                });
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Etiquetas',
                    hintText: 'Separadas por comas',
                  ),
                );
              },
              onSelected: (selection) {
                final parts = _tags.text.split(',').map((t) => t.trim()).toList();
                if (parts.isNotEmpty) parts.removeLast();
                parts.add(selection);
                _tags.text = '${parts.where((p) => p.isNotEmpty).join(', ')}, ';
              },
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

  List<Widget> _typeSpecificFields() {
    switch (_type) {
      case VaultItemType.password:
        return [
          TextField(
            controller: _username,
            decoration:
                const InputDecoration(labelText: 'Usuario', hintText: 'Ej. usuario@email.com'),
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
        ];
      case VaultItemType.card:
        return [
          TextField(
            controller: _cardholder,
            decoration: const InputDecoration(labelText: 'Titular', hintText: 'Nombre en la tarjeta'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cardNumber,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Número de tarjeta'),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _cardExpiry,
                  decoration: const InputDecoration(labelText: 'Caducidad', hintText: 'MM/AA'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AppPasswordField(controller: _cardCvv, hintText: 'CVV'),
              ),
            ],
          ),
        ];
      case VaultItemType.secureNote:
        return const [];
      case VaultItemType.identity:
        return [
          TextField(
            controller: _fullName,
            decoration: const InputDecoration(labelText: 'Nombre completo'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _documentNumber,
            decoration: const InputDecoration(labelText: 'DNI / Pasaporte'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Teléfono'),
          ),
        ];
      case VaultItemType.wifi:
        return [
          TextField(
            controller: _ssid,
            decoration: const InputDecoration(labelText: 'Nombre de red (SSID)'),
          ),
          const SizedBox(height: 16),
          AppPasswordField(
            controller: _password,
            hintText: 'Contraseña de red',
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Generar contraseña',
              onPressed: () => setState(
                () => _password.text = _generator.generate(GeneratorOptions.recommended()),
              ),
            ),
          ),
        ];
    }
  }
}
