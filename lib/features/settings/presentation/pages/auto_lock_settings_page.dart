import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// "Bloqueo automático" picker from img/08_settings.png — no mockup of its
/// own, styled like [ThemeSettingsPage]'s option list for consistency.
class AutoLockSettingsPage extends StatefulWidget {
  const AutoLockSettingsPage({super.key, this.embedded = false});

  /// True when SettingsPage renders this inline in the wide layout instead
  /// of pushing it as its own route — skips the Scaffold/AppBar, since the
  /// parent already supplies a header (with a back arrow) around it.
  final bool embedded;

  @override
  State<AutoLockSettingsPage> createState() => _AutoLockSettingsPageState();
}

class _AutoLockSettingsPageState extends State<AutoLockSettingsPage> {
  final SettingsRepository _settings = sl<SettingsRepository>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _settings.current.autoLockAfter;

    final list = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final option in autoLockOptions) ...[
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: option == current ? AppColors.primary : theme.dividerColor),
            ),
            child: InkWell(
              onTap: () async {
                await _settings.setAutoLockAfter(option);
                if (mounted) setState(() {});
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(formatAutoLockDuration(option), style: theme.textTheme.bodyLarge),
                    ),
                    if (option == current)
                      const Icon(Icons.check_circle, color: AppColors.primary)
                    else
                      Icon(Icons.circle_outlined, color: theme.dividerColor),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );

    if (widget.embedded) return list;
    return Scaffold(
      appBar: AppBar(title: const Text('Bloqueo automático')),
      body: SafeArea(child: list),
    );
  }
}
