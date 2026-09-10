import 'package:flutter/material.dart';

import '../../../../core/widgets/app_password_field.dart';

/// Formulario de creación de la contraseña maestra.
///
/// No es una de las pantallas numeradas de `/img` — no hay ningún mockup
/// de referencia para este estado exacto — así que reutiliza a propósito
/// el lenguaje visual de la pantalla de bloqueo (mismo logo, espaciado,
/// estilos de campo y botón) en vez de introducir un aspecto nuevo, según
/// el "adapta únicamente lo imprescindible".
class CreateMasterPasswordPage extends StatefulWidget {
  const CreateMasterPasswordPage({super.key, this.onCreate});

  /// Se llama con la contraseña elegida una vez pasa la validación local.
  final ValueChanged<String>? onCreate;

  static const minLength = 8;

  @override
  State<CreateMasterPasswordPage> createState() => _CreateMasterPasswordPageState();
}

class _CreateMasterPasswordPageState extends State<CreateMasterPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < CreateMasterPasswordPage.minLength) {
      setState(() => _errorText = 'Debe tener al menos ${CreateMasterPasswordPage.minLength} caracteres');
      return;
    }
    if (password != confirm) {
      setState(() => _errorText = 'Las contraseñas no coinciden');
      return;
    }

    setState(() => _errorText = null);
    widget.onCreate?.call(password);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear contraseña maestra')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                'Esta contraseña protege toda tu bóveda.\nSi la olvidas, no podrá recuperarse.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(flex: 2),
              AppPasswordField(
                controller: _passwordController,
                hintText: 'Contraseña maestra',
                autofocus: true,
              ),
              const SizedBox(height: 16),
              AppPasswordField(
                controller: _confirmController,
                hintText: 'Confirmar contraseña',
                onSubmitted: (_) => _submit(),
              ),
              if (_errorText case final error?) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    error,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Crear bóveda'),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
