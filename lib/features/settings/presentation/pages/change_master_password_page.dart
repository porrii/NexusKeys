import 'package:flutter/material.dart';

import '../../../../core/database/vault_session.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/secure_bytes.dart';
import '../../../../core/widgets/app_password_field.dart';
import '../../../auth/domain/entities/auth_result.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/pages/create_master_password_page.dart';

/// "Cambiar contraseña maestra" de img/08_settings.png. Sin mockup propio —
/// reutiliza la distribución de campos y la validación del formulario de
/// crear contraseña.
///
/// Cambiar la contraseña maestra tiene que volver a cifrar *dos* cosas que
/// todos los demás flujos que las tocan mantienen sincronizadas: el
/// verificador de autenticación (lo que rota
/// [AuthRepository.changeMasterPassword]) y la propia base de datos de la
/// bóveda, que sigue cifrada bajo la clave que se derivó al desbloquear
/// hasta que algo diga lo contrario. Saltarse el segundo paso dejaría la
/// bóveda permanentemente indescifrable en el momento en que esto "tenga
/// éxito".
class ChangeMasterPasswordPage extends StatefulWidget {
  const ChangeMasterPasswordPage({super.key, this.embedded = false, this.onDone});

  /// True cuando SettingsPage la renderiza en línea en el layout ancho en
  /// vez de empujarla como su propia ruta — se salta el Scaffold/AppBar y,
  /// al terminar bien, llama a [onDone] en vez de hacer pop (no hay ruta
  /// que cerrar).
  final bool embedded;

  /// Se llama tras un cambio de contraseña correcto cuando [embedded] — la
  /// vía no embebida muestra un SnackBar y hace pop en su lugar.
  final VoidCallback? onDone;

  @override
  State<ChangeMasterPasswordPage> createState() => _ChangeMasterPasswordPageState();
}

class _ChangeMasterPasswordPageState extends State<ChangeMasterPasswordPage> {
  final AuthRepository _authRepository = sl<AuthRepository>();
  final VaultSession _vaultSession = sl<VaultSession>();

  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isBusy = false;
  String? _errorText;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentController.text;
    final newPassword = _newController.text;
    final confirm = _confirmController.text;

    if (newPassword.length < CreateMasterPasswordPage.minLength) {
      setState(() => _errorText = 'Debe tener al menos ${CreateMasterPasswordPage.minLength} caracteres');
      return;
    }
    if (newPassword != confirm) {
      setState(() => _errorText = 'Las contraseñas no coinciden');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    final result = await _authRepository.changeMasterPassword(
      currentPassword: current,
      newPassword: newPassword,
    );

    switch (result) {
      case AuthSuccess(:final vaultKey):
        _vaultSession.rekey(vaultKey);
        wipe(vaultKey);
        if (!mounted) return;
        if (widget.embedded) {
          widget.onDone?.call();
        } else {
          Navigator.of(context).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña maestra actualizada')),
        );
      case AuthFailure(:final reason):
        setState(() {
          _isBusy = false;
          _errorText = switch (reason) {
            AuthFailureReason.wrongPassword => 'La contraseña actual no es correcta',
            AuthFailureReason.vaultNotInitialized => 'No hay ninguna bóveda configurada',
            AuthFailureReason.corruptedAuthData => 'Los datos de autenticación están dañados',
          };
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final form = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppPasswordField(
          controller: _currentController,
          hintText: 'Contraseña actual',
          autofocus: true,
        ),
        const SizedBox(height: 16),
        AppPasswordField(controller: _newController, hintText: 'Nueva contraseña'),
        const SizedBox(height: 16),
        AppPasswordField(
          controller: _confirmController,
          hintText: 'Confirmar nueva contraseña',
          onSubmitted: (_) => _submit(),
        ),
        if (_errorText case final error?) ...[
          const SizedBox(height: 12),
          Text(error, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isBusy ? null : _submit,
            child: _isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Guardar'),
          ),
        ),
      ],
    );

    if (widget.embedded) return form;
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña maestra')),
      body: SafeArea(child: form),
    );
  }
}
