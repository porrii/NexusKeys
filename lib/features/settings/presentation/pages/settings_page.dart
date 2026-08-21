import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import 'auto_lock_settings_page.dart';
import 'change_master_password_page.dart';
import 'language_settings_page.dart';
import 'theme_settings_page.dart';
import 'trash_page.dart';

/// Reproduces img/08_settings.png.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsRepository _settings = sl<SettingsRepository>();

  static const _themeLabels = {
    AppThemeMode.light: 'Claro',
    AppThemeMode.dark: 'Oscuro',
    AppThemeMode.oled: 'OLED',
    AppThemeMode.system: 'Seguir sistema',
  };

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disponible próximamente')),
    );
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings.current;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const _SectionHeader('SEGURIDAD'),
            _SettingsTile(
              title: 'Bloqueo automático',
              value: formatAutoLockDuration(settings.autoLockAfter),
              onTap: () => _push(const AutoLockSettingsPage()),
            ),
            _SettingsTile(
              title: 'Cambiar contraseña maestra',
              onTap: () => _push(const ChangeMasterPasswordPage()),
            ),
            _SettingsTile(
              title: 'Autenticación biométrica',
              value: settings.biometricEnabled ? 'Activada' : 'Desactivada',
              onTap: _showComingSoon,
            ),
            _SettingsSwitchTile(
              title: 'Bloquear al cerrar',
              value: settings.lockOnClose,
              onChanged: (value) async {
                await _settings.setLockOnClose(value);
                if (mounted) setState(() {});
              },
            ),
            const _SectionHeader('GENERAL'),
            _SettingsTile(
              title: 'Tema',
              value: _themeLabels[settings.themeMode],
              onTap: () => _push(const ThemeSettingsPage()),
            ),
            _SettingsTile(
              title: 'Idioma',
              value: 'Español',
              onTap: () => _push(const LanguageSettingsPage()),
            ),
            _SettingsTile(title: 'Gestionar categorías', onTap: _showComingSoon),
            _SettingsTile(title: 'Papelera', onTap: () => _push(const TrashPage())),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.title, this.value, this.onTap});

  final String title;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(title, style: theme.textTheme.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) ...[
            Text(value!, style: theme.textTheme.bodyMedium),
            const SizedBox(width: 6),
          ],
          Icon(Icons.chevron_right, color: theme.textTheme.bodyMedium?.color),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({required this.title, required this.value, required this.onChanged});

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      value: value,
      onChanged: onChanged,
    );
  }
}
