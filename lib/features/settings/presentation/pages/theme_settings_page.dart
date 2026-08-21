import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// Reproduces img/12_theme.png.
class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  final SettingsRepository _settings = sl<SettingsRepository>();

  static const _options = [
    (mode: AppThemeMode.light, label: 'Claro', icon: Icons.wb_sunny_outlined),
    (mode: AppThemeMode.dark, label: 'Oscuro', icon: Icons.nightlight_round),
    (mode: AppThemeMode.oled, label: 'OLED', icon: Icons.circle_outlined),
    (mode: AppThemeMode.system, label: 'Seguir sistema', icon: Icons.desktop_windows_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final current = _settings.current.themeMode;

    return Scaffold(
      appBar: AppBar(title: const Text('Tema')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final option in _options) ...[
              _ThemeOptionTile(
                label: option.label,
                icon: option.icon,
                selected: current == option.mode,
                onTap: () async {
                  await _settings.setThemeMode(option.mode);
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? AppColors.primary : theme.dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: theme.textTheme.bodyLarge?.color),
              const SizedBox(width: 16),
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.primary)
              else
                Icon(Icons.circle_outlined, color: theme.dividerColor),
            ],
          ),
        ),
      ),
    );
  }
}
