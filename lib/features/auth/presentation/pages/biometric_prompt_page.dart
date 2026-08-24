import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/services/vault_key_store.dart';

/// Reproduces img/10_biometric.png. Shown when the user taps the fingerprint
/// icon on the lock screen — this is NexusKeys' own branded rationale
/// screen, not the actual capture UI, since Flutter has no direct sensor
/// access. The real fingerprint/face capture happens in the OS's own
/// `BiometricPrompt`, shown natively by [VaultKeyStore.read] itself: the
/// stored key's Keystore entry requires user authentication to decrypt, so
/// there is nothing else to trigger it from here.
///
/// Pops with the retrieved vault key on success, or `null` on cancel or a
/// failed/declined attempt. The caller (AuthGatePage) unlocks
/// [VaultSession] with the result exactly the way it does after a
/// password-based [AuthSuccess] — this page never touches the session
/// itself.
class BiometricPromptPage extends StatefulWidget {
  const BiometricPromptPage({super.key});

  @override
  State<BiometricPromptPage> createState() => _BiometricPromptPageState();
}

class _BiometricPromptPageState extends State<BiometricPromptPage> {
  final VaultKeyStore _vaultKeyStore = sl<VaultKeyStore>();

  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    final Uint8List? vaultKey = await _vaultKeyStore.read();
    if (!mounted) return;

    if (vaultKey == null) {
      setState(() => _isAuthenticating = false);
      return;
    }

    Navigator.of(context).pop(vaultKey);
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
              Image.asset('assets/images/logo_mark.png', width: 64, height: 64),
              const SizedBox(height: 20),
              Text('Confirmar identidad', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                'Usa tu huella dactilar para continuar',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(flex: 3),
              GestureDetector(
                onTap: _isAuthenticating ? null : _authenticate,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: _isAuthenticating
                      ? SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : Icon(Icons.fingerprint, size: 48, color: theme.colorScheme.primary),
                ),
              ),
              const Spacer(flex: 4),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
