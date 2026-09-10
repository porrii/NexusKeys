import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/services/biometric_service.dart';
import '../../domain/services/vault_key_store.dart';

/// Reproduce img/10_biometric.png. Se muestra cuando el usuario pulsa el
/// icono de huella en la pantalla de bloqueo — es la pantalla de
/// justificación con la marca de NexusKeys, no la UI de captura real, ya
/// que Flutter no tiene acceso directo al sensor. La captura real de
/// huella/cara ocurre en el propio `BiometricPrompt` del SO.
///
/// Hace pop con la clave de la bóveda recuperada si tiene éxito, o `null`
/// si se cancela o el intento falla/se rechaza. Quien llama (AuthGatePage)
/// desbloquea [VaultSession] con el resultado exactamente igual que
/// después de un [AuthSuccess] por contraseña — esta página nunca toca la
/// sesión en sí.
class BiometricPromptPage extends StatefulWidget {
  const BiometricPromptPage({super.key});

  @override
  State<BiometricPromptPage> createState() => _BiometricPromptPageState();
}

class _BiometricPromptPageState extends State<BiometricPromptPage> {
  final VaultKeyStore _vaultKeyStore = sl<VaultKeyStore>();
  final BiometricService _biometricService = sl<BiometricService>();

  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    // La entrada del Keystore de [VaultKeyStore.read] exige autenticación
    // del usuario para descifrarse — pero flutter_secure_storage solo
    // muestra ese prompt nativo la *primera* vez que este proceso de la
    // app la toca; después mantiene el cifrado ya desbloqueado en memoria y
    // lo reutiliza en silencio durante el resto del proceso.
    // [hasWarmedUpCipher] dice de qué caso se trata: false la primera vez
    // (el read() de abajo va a mostrar el prompt real él mismo — volver a
    // preguntar antes solo lo duplicaría), true cada vez después (read()
    // ahora desbloquearía en silencio por su cuenta, así que este es el
    // único prompt que va a preguntar de verdad).
    if (_vaultKeyStore.hasWarmedUpCipher) {
      final confirmed = await _biometricService.authenticate(
        reason: 'Usa tu huella dactilar para continuar',
      );
      if (!mounted) return;
      if (!confirmed) {
        setState(() => _isAuthenticating = false);
        return;
      }
    }

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
