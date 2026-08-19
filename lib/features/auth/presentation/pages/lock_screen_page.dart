import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_password_field.dart';

/// Vault unlock screen — reproduces img/01_lock.png.
///
/// This is the presentation shell only: it exposes callbacks for the
/// actions a viewer can trigger (unlock, biometric unlock, other options)
/// without depending on the authentication domain layer, which is wired in
/// separately once Argon2id/AES-GCM verification is implemented.
class LockScreenPage extends StatefulWidget {
  const LockScreenPage({
    super.key,
    this.onUnlock,
    this.onBiometricUnlock,
    this.onOtherOptions,
    this.biometricAvailable = true,
  });

  final ValueChanged<String>? onUnlock;
  final VoidCallback? onBiometricUnlock;
  final VoidCallback? onOtherOptions;
  final bool biometricAvailable;

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

  void _submit() => widget.onUnlock?.call(_passwordController.text);

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
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Desbloquear'),
                ),
              ),
              const SizedBox(height: 28),
              IconButton(
                iconSize: 36,
                onPressed: widget.biometricAvailable ? widget.onBiometricUnlock : null,
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
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
