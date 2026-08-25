import 'package:flutter/material.dart';

import '../../../../core/security/password_strength.dart';
import '../../../../core/widgets/password_strength_indicator.dart';
import '../../domain/entities/vault_item.dart';
import '../../domain/entities/vault_item_type.dart';

/// The type-specific field cards for [item] — a card's number and CVV, an
/// identity's document number, ... — built from [VaultItem.extraData].
/// Shared between [ItemDetailsPage] and the wide layout's detail pane so
/// both stay in sync as new types/fields are added, rather than
/// maintaining the same switch twice.
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

/// A single labelled field row on the item details view — reused by both
/// [ItemDetailsPage] (img/04_item_details.png, mobile) and the inline
/// detail pane on wide layouts (img/13_tablet.png, img/14_windows.png),
/// which show the exact same field cards without their own Scaffold/AppBar.
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

/// A shorter, obscured field without the password-strength meter that
/// makes sense for an actual password but not for e.g. a card's CVV.
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
