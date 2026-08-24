import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/security/secure_bytes.dart';
import '../../../../core/widgets/app_password_field.dart';
import '../../../auth/domain/entities/auth_result.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/domain/services/biometric_service.dart';
import '../../../auth/domain/services/vault_key_store.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import 'auto_lock_settings_page.dart';
import 'categories_page.dart';
import 'change_master_password_page.dart';
import 'language_settings_page.dart';
import 'tags_page.dart';
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
  final BiometricService _biometricService = sl<BiometricService>();
  final VaultKeyStore _vaultKeyStore = sl<VaultKeyStore>();
  final AuthRepository _authRepository = sl<AuthRepository>();

  static const _themeLabels = {
    AppThemeMode.light: 'Claro',
    AppThemeMode.dark: 'Oscuro',
    AppThemeMode.oled: 'OLED',
    AppThemeMode.system: 'Seguir sistema',
  };

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  /// Disabling just clears the stored key. Enabling needs the master
  /// password re-entered first: Settings never has the raw vault key lying
  /// around (it's wiped right after the vault is unlocked), so this is the
  /// only place that can derive a fresh copy to hand to [VaultKeyStore].
  Future<void> _toggleBiometric() async {
    final available = await _biometricService.isDeviceSupported();
    if (!mounted) return;
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este dispositivo no admite autenticación biométrica.')),
      );
      return;
    }

    if (_settings.current.biometricEnabled) {
      await _vaultKeyStore.clear();
      await _settings.setBiometricEnabled(false);
      if (mounted) setState(() {});
      return;
    }

    final password = await _promptForPassword();
    if (password == null || !mounted) return;

    final result = await _authRepository.verifyMasterPassword(password);
    if (!mounted) return;
    if (result is! AuthSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña incorrecta.')),
      );
      return;
    }

    final vaultKey = result.vaultKey;
    // VaultKeyStore.save writes to a Keystore entry that requires user
    // authentication to even encrypt into, so this alone is what shows the
    // native biometric prompt — no separate BiometricService call needed
    // here, that would just prompt the user twice.
    bool saved = false;
    try {
      await _vaultKeyStore.save(vaultKey);
      saved = true;
    } on Exception {
      saved = false;
    } finally {
      wipe(vaultKey);
    }
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo activar el desbloqueo biométrico.')),
      );
      return;
    }

    await _settings.setBiometricEnabled(true);
    if (mounted) setState(() {});
  }

  Future<String?> _promptForPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirma tu contraseña maestra'),
        content: AppPasswordField(
          controller: controller,
          hintText: 'Contraseña maestra',
          autofocus: true,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
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
              onTap: _toggleBiometric,
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
            _SettingsTile(
              title: 'Gestionar categorías',
              onTap: () => _push(const CategoriesPage()),
            ),
            _SettingsTile(title: 'Etiquetas', onTap: () => _push(const TagsPage())),
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
