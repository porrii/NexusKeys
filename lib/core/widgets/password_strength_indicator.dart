import 'package:flutter/material.dart';

import '../security/password_strength.dart';

/// A colored progress bar + label, e.g. img/04_item_details.png's green
/// "Fuerte" indicator under a password. Shared with the Generator module
/// later so both use the same visual for the same [PasswordStrength].
class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({required this.strength, super.key});

  final PasswordStrength strength;

  double get _progress => strength.segments / 5;

  @override
  Widget build(BuildContext context) {
    if (strength == PasswordStrength.empty) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 6,
              backgroundColor: strength.color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(strength.color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          strength.label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: strength.color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
