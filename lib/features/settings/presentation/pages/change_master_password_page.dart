import 'package:flutter/material.dart';

import '../../../../core/database/vault_session.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/secure_bytes.dart';
import '../../../../core/widgets/app_password_field.dart';
import '../../../auth/domain/entities/auth_result.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/pages/create_master_password_page.dart';

/// "Cambiar contraseña maestra" from img/08_settings.png. No mockup of its
/// own — reuses the create-password form's field layout and validation.
///
/// Changing the master password has to re-key *two* things kept in sync by
/// every other flow that touches them: the auth verifier (what
/// [AuthRepository.changeMasterPassword] rotates) and the vault database
/// itself, which stays encrypted under whatever key was derived at unlock
/// time until something tells it otherwise. Skipping the second step would
/// leave the vault permanently undecryptable the moment this "succeeds".
class ChangeMasterPasswordPage extends StatefulWidget {
  const ChangeMasterPasswordPage({super.key});

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
        Navigator.of(context).pop();
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

    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña maestra')),
      body: SafeArea(
        child: ListView(
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
        ),
      ),
    );
  }
}
