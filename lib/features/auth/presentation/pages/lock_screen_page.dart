import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_password_field.dart';

/// Pantalla de desbloqueo de la bóveda — reproduce img/01_lock.png.
///
/// Es solo la envoltura de presentación: expone callbacks para las
/// acciones que puede disparar quien la ve (desbloquear, desbloqueo
/// biométrico, otras opciones) sin depender de la capa de dominio de
/// autenticación, que se conecta aparte una vez implementada la
/// verificación Argon2id/AES-GCM.
class LockScreenPage extends StatefulWidget {
  const LockScreenPage({
    super.key,
    this.onUnlock,
    this.onBiometricUnlock,
    this.onOtherOptions,
    this.biometricAvailable = true,
    this.isUnlocking = false,
    this.errorText,
  });

  final ValueChanged<String>? onUnlock;
  final VoidCallback? onBiometricUnlock;
  final VoidCallback? onOtherOptions;
  final bool biometricAvailable;

  /// Muestra un spinner en el botón de desbloquear y desactiva la entrada
  /// mientras sea true.
  final bool isUnlocking;

  /// Aviso del último intento fallido (p. ej. "Contraseña incorrecta").
  /// Null cuando no hay nada que mostrar.
  final String? errorText;

  @override
  State<LockScreenPage> createState() => _LockScreenPageState();
}

class _LockScreenPageState extends State<LockScreenPage> {
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.isUnlocking) return;
    widget.onUnlock?.call(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Image.asset(
                'assets/images/logo_mark.png',
                width: 76,
                height: 76,
              ),
              const SizedBox(height: 18),
              Text('NexusKeys', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text('Desbloquear bóveda', style: theme.textTheme.bodyMedium),
              const Spacer(flex: 4),
              AppPasswordField(
                controller: _passwordController,
                hintText: 'Contraseña maestra',
                autofocus: true,
                onSubmitted: (_) => _submit(),
              ),
              if (widget.errorText case final error?) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    error,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.isUnlocking ? null : _submit,
                  child: widget.isUnlocking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Desbloquear'),
                ),
              ),
              // Se ocultan del todo, no solo se deshabilitan, cuando no hay
              // desbloqueo biométrico configurado — todavía no hay nada a
              // lo que recurrir, así que un icono de huella atenuado y un
              // "Otras opciones" que no hace nada solo serían ruido visual.
              if (widget.biometricAvailable) ...[
                const SizedBox(height: 28),
                IconButton(
                  iconSize: 36,
                  onPressed: widget.isUnlocking ? null : widget.onBiometricUnlock,
                  icon: const Icon(Icons.fingerprint),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: widget.onOtherOptions,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    minimumSize: const Size(0, 44),
                    textStyle: AppTextStyles.body,
                  ),
                  child: const Text('Otras opciones'),
                ),
              ],
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
