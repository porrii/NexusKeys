import 'package:flutter/material.dart';

import '../security/password_strength.dart';

/// Cinco pastillas discretas, tantas rellenas como
/// [PasswordStrength.segments] — el medidor de fortaleza de
/// img/06_generator.png, distinto de la barra continua de
/// [PasswordStrengthIndicator] en la pantalla de detalles del elemento
/// porque es lo que muestra su propio mockup.
class SegmentedStrengthIndicator extends StatelessWidget {
  const SegmentedStrengthIndicator({required this.strength, super.key});

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactiveColor = theme.dividerColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Fortaleza', style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(
              strength.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: strength.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < 5; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    height: 6,
                    color: i < strength.segments ? strength.color : inactiveColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
