import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Pantalla de primer arranque — reproduce img/02_welcome.png. Se muestra
/// solo cuando aún no se ha configurado ninguna contraseña maestra.
class WelcomePage extends StatelessWidget {
  const WelcomePage({
    super.key,
    this.onCreateVault,
    this.onOpenExistingVault,
  });

  final VoidCallback? onCreateVault;
  final VoidCallback? onOpenExistingVault;

  static const _bullets = [
    'Sin conexión a internet',
    'Tus datos, solo tuyos',
    'Cifrado de extremo a extremo',
  ];

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
              Image.asset('assets/images/logo_mark.png', width: 76, height: 76),
              const SizedBox(height: 18),
              Text('NexusKeys', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Tu bóveda de contraseñas\n100% offline y segura',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(flex: 3),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final bullet in _bullets) ...[
                      _FeatureBullet(text: bullet),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onCreateVault,
                  child: const Text('Crear nueva bóveda'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onOpenExistingVault,
                child: const Text('Abrir bóveda existente'),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Text(text, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}
