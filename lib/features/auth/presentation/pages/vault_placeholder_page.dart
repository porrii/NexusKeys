import 'package:flutter/material.dart';

/// Temporary landing page shown after a successful unlock/setup.
///
/// This is *not* one of the designed screens — img/03_vault.png is reproduced
/// in its own module — it only exists so the auth flow (create → unlock →
/// lock again) is fully testable end-to-end before the vault UI exists.
class VaultPlaceholderPage extends StatelessWidget {
  const VaultPlaceholderPage({super.key, this.onLock});

  final VoidCallback? onLock;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_open_outlined, size: 48),
            const SizedBox(height: 16),
            Text('Bóveda desbloqueada', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'La interfaz de la bóveda se implementa en un módulo posterior.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onLock, child: const Text('Bloquear')),
          ],
        ),
      ),
    );
  }
}
