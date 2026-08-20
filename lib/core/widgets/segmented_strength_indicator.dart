import 'package:flutter/material.dart';

import '../security/password_strength.dart';

/// Five discrete pills, as many filled as [PasswordStrength.segments] —
/// img/06_generator.png's strength meter, distinct from
/// [PasswordStrengthIndicator]'s continuous bar on the item details screen
/// because that's what its own mockup shows.
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
