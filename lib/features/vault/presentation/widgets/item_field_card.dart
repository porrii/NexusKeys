import 'package:flutter/material.dart';

import '../../../../core/security/password_strength.dart';
import '../../../../core/widgets/password_strength_indicator.dart';
import '../../domain/entities/vault_item.dart';
import '../../domain/entities/vault_item_type.dart';

/// Las tarjetas de campo específicas de cada tipo para [item] — el número
/// y el CVV de una tarjeta, el número de documento de una identidad, ... —
/// construidas a partir de [VaultItem.extraData]. Compartidas entre
/// [ItemDetailsPage] y el panel de detalle del layout ancho para que ambos
/// se mantengan sincronizados al añadir tipos/campos nuevos, en vez de
/// mantener el mismo switch dos veces.
List<Widget> buildExtraDataFields({
  required BuildContext context,
  required VaultItem item,
  required void Function(String label, String value) onCopy,
}) {
  final theme = Theme.of(context);
  final extra = item.extraData;
  final widgets = <Widget>[];

  void addField(String label, String? value, {bool masked = false}) {
    if (value == null || value.isEmpty) return;
    widgets.add(const SizedBox(height: 14));
    widgets.add(
      masked
          ? ItemMaskedFieldCard(label: label, value: value, onCopy: () => onCopy(label, value))
          : ItemFieldCard(
              label: label,
              onCopy: () => onCopy(label, value),
              child: Text(value, style: theme.textTheme.bodyLarge),
            ),
    );
  }

  switch (item.type) {
    case VaultItemType.card:
      addField('Titular', extra[VaultItem.keyCardholder]);
      addField('Número de tarjeta', extra[VaultItem.keyCardNumber]);
      addField('Caducidad', extra[VaultItem.keyCardExpiry]);
      addField('CVV', extra[VaultItem.keyCardCvv], masked: true);
    case VaultItemType.identity:
      addField('Nombre completo', extra[VaultItem.keyFullName]);
      addField('DNI / Pasaporte', extra[VaultItem.keyDocumentNumber]);
      addField('Teléfono', extra[VaultItem.keyPhone]);
    case VaultItemType.wifi:
      addField('Nombre de red (SSID)', extra[VaultItem.keySsid]);
    case VaultItemType.password:
    case VaultItemType.secureNote:
      break;
  }

  return widgets;
}

/// Una única fila de campo etiquetada en la vista de detalles del elemento
/// — reutilizada tanto por [ItemDetailsPage] (img/04_item_details.png,
/// móvil) como por el panel de detalle en línea de los layouts anchos
/// (img/13_tablet.png, img/14_windows.png), que muestran exactamente las
/// mismas tarjetas de campo sin su propio Scaffold/AppBar.
class ItemFieldCard extends StatelessWidget {
  const ItemFieldCard({required this.label, required this.child, this.icon, this.onCopy, super.key});

  final String label;
  final Widget child;
  final IconData? icon;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: theme.textTheme.bodyMedium?.color),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  child,
                ],
              ),
            ),
            if (onCopy != null)
              IconButton(icon: const Icon(Icons.copy_outlined), onPressed: onCopy),
          ],
        ),
      ),
    );
  }
}

/// Un campo más corto y oculto, sin el medidor de fortaleza de contraseña
/// que tiene sentido para una contraseña de verdad pero no para, p. ej.,
/// el CVV de una tarjeta.
class ItemMaskedFieldCard extends StatefulWidget {
  const ItemMaskedFieldCard({required this.label, required this.value, this.onCopy, super.key});

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  State<ItemMaskedFieldCard> createState() => _ItemMaskedFieldCardState();
}

class _ItemMaskedFieldCardState extends State<ItemMaskedFieldCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ItemFieldCard(
      label: widget.label,
      onCopy: widget.onCopy,
      child: Row(
        children: [
          Expanded(
            child: Text(
              _revealed ? widget.value : '•' * widget.value.length,
              style: theme.textTheme.bodyLarge?.copyWith(letterSpacing: 1.2),
            ),
          ),
          IconButton(
            icon: Icon(_revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _revealed = !_revealed),
          ),
        ],
      ),
    );
  }
}

class ItemPasswordFieldCard extends StatefulWidget {
  const ItemPasswordFieldCard({required this.password, this.onCopy, super.key});

  final String password;
  final VoidCallback? onCopy;

  @override
  State<ItemPasswordFieldCard> createState() => _ItemPasswordFieldCardState();
}

class _ItemPasswordFieldCardState extends State<ItemPasswordFieldCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayed = _revealed ? widget.password : '•' * widget.password.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Contraseña', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        displayed,
                        style: theme.textTheme.bodyLarge?.copyWith(letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _revealed = !_revealed),
                ),
                if (widget.onCopy != null)
                  IconButton(icon: const Icon(Icons.copy_outlined), onPressed: widget.onCopy),
              ],
            ),
            const SizedBox(height: 6),
            PasswordStrengthIndicator(strength: evaluatePasswordStrength(widget.password)),
          ],
        ),
      ),
    );
  }
}
