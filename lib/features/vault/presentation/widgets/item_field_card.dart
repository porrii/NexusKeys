import 'package:flutter/material.dart';

import '../../../../core/security/password_strength.dart';
import '../../../../core/widgets/password_strength_indicator.dart';

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
