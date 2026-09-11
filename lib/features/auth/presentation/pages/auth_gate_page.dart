import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/database/vault_session.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/secure_bytes.dart';
import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/services/biometric_service.dart';
import '../../../backup/presentation/pages/import_export_page.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../../vault/domain/repositories/vault_repository.dart';
import '../../../vault/presentation/pages/vault_page.dart';
import 'biometric_prompt_page.dart';
import 'create_master_password_page.dart';
import 'lock_screen_page.dart';
import 'welcome_page.dart';

enum _Screen { loading, welcome, lock, vault }

/// Decide qué pantalla abre la app: [WelcomePage] si aún no se ha
/// configurado ninguna contraseña maestra, [LockScreenPage] en caso
/// contrario. Es dueña de la navegación entre todas las pantallas del
/// flujo de autenticación para que cada página siga siendo una envoltura
/// de presentación pura y fácil de testear.
///
/// [welcome], [lock] y [vault] se intercambian en el sitio con [setState]
/// en vez de empujarse como rutas separadas — este widget vive durante
/// toda la sesión de la app, así que su `context` nunca lo invalida una
/// transición de ruta como pasaría si un callback capturase el context de
/// una página que se hubiera cerrado o reemplazado. [CreateMasterPasswordPage]
/// es la única subpantalla de verdad, a la que se llega con un push/pop
/// normal porque tiene su propio botón de volver.
class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> with WidgetsBindingObserver {
  final AuthRepository _authRepository = sl<AuthRepository>();
  final VaultSession _vaultSession = sl<VaultSession>();
  final BiometricService _biometricService = sl<BiometricService>();
  final SettingsRepository _settings = sl<SettingsRepository>();

  _Screen _screen = _Screen.loading;
  bool _isBusy = false;
  bool _biometricAvailable = false;
  String? _lockScreenError;

  /// Se fija en el momento en que la app deja el primer plano, para que
  /// [didChangeAppLifecycleState] pueda saber al volver cuánto tiempo
  /// estuvo fuera — es contra eso contra lo que mide de verdad el "Bloqueo
  /// automático". Se limpia al volver.
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkVaultStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// "Bloquear al cerrar" y "Bloqueo automático" (Ajustes > SEGURIDAD) eran
  /// dos ajustes que se guardaban sin que nada los aplicara en ningún sitio
  /// — esto es esa aplicación. Solo importa mientras la bóveda está
  /// desbloqueada; no hay nada que proteger en las pantallas de
  /// bienvenida/bloqueo/carga.
  ///
  /// "Bloquear al cerrar" bloquea en el instante en que la app deja el
  /// primer plano, por breve que sea — no espera a ver si vuelves.
  /// "Bloqueo automático" es la alternativa más suave para cuando eso está
  /// desactivado: solo bloquea si de verdad has estado fuera al menos ese
  /// tiempo, comprobado al volver en vez de con un temporizador en segundo
  /// plano (el contenido de la bóveda no está en pantalla mientras está en
  /// segundo plano de todas formas, así que comprobar al volver — antes de
  /// mostrar nada de nuevo — es suficiente).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_screen != _Screen.vault) return;

    switch (state) {
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (backgroundedAt == null) return;
        final autoLockAfter = _settings.current.autoLockAfter;
        if (autoLockAfter == null) return; // "Nunca"
        if (DateTime.now().difference(backgroundedAt) >= autoLockAfter) {
          _lockVault();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now();
        if (_settings.current.lockOnClose) _lockVault();
      case AppLifecycleState.detached:
        if (_settings.current.lockOnClose) _vaultSession.lock();
    }
  }

  Future<void> _checkVaultStatus() async {
    final initialized = await _authRepository.isVaultInitialized();
    if (!mounted) return;
    setState(() {
      _screen = initialized ? _Screen.lock : _Screen.welcome;
      // Se resuelve aparte, cuando la pantalla de bloqueo ya está en
      // pantalla — ver el comentario de _refreshBiometricAvailability.
      _biometricAvailable = false;
    });
    if (initialized) unawaited(_refreshBiometricAvailability());
  }

  /// Si mostrar el icono de huella en la pantalla de bloqueo —
  /// deliberadamente comprobado *después* de que [_checkVaultStatus] ya
  /// haya puesto la pantalla de bloqueo en pantalla, no como parte de ella.
  /// [BiometricService.isDeviceSupported] llama a las APIs biométricas de
  /// la plataforma, y en al menos un dispositivo real eso solo bastaba para
  /// sacar un prompt biométrico nativo antes de que la propia pantalla de
  /// bloqueo de NexusKeys se hubiera pintado siquiera — pidiendo al usuario
  /// autenticarse antes de que hubiera elegido desbloquear. Ejecutar esto a
  /// posteriori significa que lo primero que te recibe siempre es la
  /// pantalla de bloqueo, no un prompt biométrico.
  Future<void> _refreshBiometricAvailability() async {
    final available =
        _settings.current.biometricEnabled && await _biometricService.isDeviceSupported();
    if (!mounted || _screen != _Screen.lock) return;
    setState(() => _biometricAvailable = available);
  }

  void _openCreatePasswordPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateMasterPasswordPage(onCreate: _submitNewMasterPassword),
      ),
    );
  }

  Future<void> _submitNewMasterPassword(String password) async {
    try {
      final result = await _authRepository.setupMasterPassword(password);
      if (!mounted) return;

      switch (result) {
        case AuthSuccess(:final vaultKey):
          await _vaultSession.unlock(vaultKey);
          wipe(vaultKey);
          await sl<VaultRepository>().reload();
          if (!mounted) return;
          Navigator.of(context).pop();
          setState(() => _screen = _Screen.vault);
        case AuthFailure():
          // setupMasterPassword solo falla por errores inesperados de
          // almacenamiento — hazlo visible en vez de descartarlo en silencio.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo crear la bóveda. Inténtalo de nuevo.')),
          );
      }
    } catch (_) {
      // Cualquier excepción inesperada de por aquí (derivar la clave,
      // abrir la base de datos, ...) tiene que acabar en un aviso, nunca
      // dejar el botón "Crear bóveda" sin hacer nada para siempre — ver el
      // mismo razonamiento en _handleUnlock.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear la bóveda. Inténtalo de nuevo.')),
      );
    }
  }

  Future<void> _handleUnlock(String password) async {
    setState(() {
      _isBusy = true;
      _lockScreenError = null;
    });
    // Todo lo de aquí abajo va en un try/catch a propósito: un fallo real
    // (un cuelgue de Argon2id rastreado hasta aquí, un error de E/S al
    // abrir la base de datos, cualquier cosa inesperada) no debe dejar
    // _isBusy en true para siempre — eso deja el botón "Desbloquear"
    // mostrando el spinner sin parar nunca, sin ningún error visible ni
    // forma de reintentar salvo cerrando la app. Da igual qué lance la
    // excepción: siempre se recupera aquí.
    try {
      final result = await _authRepository.verifyMasterPassword(password);
      if (!mounted) return;

      switch (result) {
        case AuthSuccess(:final vaultKey):
          await _vaultSession.unlock(vaultKey);
          wipe(vaultKey);
          await sl<VaultRepository>().reload();
          if (!mounted) return;
          setState(() {
            _isBusy = false;
            _screen = _Screen.vault;
          });
        case AuthFailure(:final reason):
          setState(() {
            _isBusy = false;
            _lockScreenError = switch (reason) {
              AuthFailureReason.wrongPassword => 'Contraseña incorrecta',
              AuthFailureReason.vaultNotInitialized => 'No hay ninguna bóveda configurada',
              AuthFailureReason.corruptedAuthData =>
                'Los datos de autenticación están dañados',
            };
          });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _lockScreenError = 'No se pudo desbloquear la bóveda. Inténtalo de nuevo.';
      });
    }
  }

  Future<void> _handleBiometricUnlock() async {
    final vaultKey = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => const BiometricPromptPage()),
    );
    if (vaultKey == null || !mounted) return;

    try {
      await _vaultSession.unlock(vaultKey);
      wipe(vaultKey);
      await sl<VaultRepository>().reload();
      if (!mounted) return;
      setState(() => _screen = _Screen.vault);
    } catch (_) {
      // La huella ya se confirmó en BiometricPromptPage — lo que falla
      // aquí es abrir la bóveda en sí (E/S, base de datos, ...). Sin este
      // catch, la excepción se perdería en silencio y la pantalla de
      // bloqueo se quedaría tal cual, sin ningún aviso de qué pasó.
      wipe(vaultKey);
      if (!mounted) return;
      setState(() => _lockScreenError = 'No se pudo desbloquear la bóveda. Inténtalo de nuevo.');
    }
  }

  void _lockVault() {
    _vaultSession.lock();
    setState(() {
      _screen = _Screen.lock;
      _lockScreenError = null;
    });
    // Vuelve a comprobar por si el desbloqueo biométrico se acaba de
    // activar/desactivar desde Ajustes durante esta sesión —
    // _biometricAvailable solo se calculó una vez, en el arranque en frío.
    _checkVaultStatus();
  }

  /// La bóveda (cabecera de autenticación + archivo de base de datos) se
  /// acaba de borrar desde el "Eliminar bóveda permanentemente" de Ajustes
  /// — no queda nada que desbloquear, así que esto va directo a
  /// [WelcomePage] en vez de a la pantalla de bloqueo que mostraría
  /// [_lockVault].
  void _handleVaultDeleted() {
    _vaultSession.lock();
    setState(() {
      _screen = _Screen.welcome;
      _lockScreenError = null;
    });
  }

  void _openImportExisting() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImportExportPage(
          showExportSection: false,
          onImportComplete: () {
            Navigator.of(context).pop();
            // Ahora existe una bóveda donde no la había — vuelve a
            // comprobar en vez de asumir .lock, por si la propia
            // importación no dejó una cabecera de autenticación bien
            // formada.
            _checkVaultStatus();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (_screen) {
      _Screen.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
      _Screen.welcome => WelcomePage(
          onCreateVault: _openCreatePasswordPage,
          onOpenExistingVault: _openImportExisting,
        ),
      _Screen.lock => LockScreenPage(
          isUnlocking: _isBusy,
          errorText: _lockScreenError,
          onUnlock: _handleUnlock,
          biometricAvailable: _biometricAvailable,
          onBiometricUnlock: _biometricAvailable ? _handleBiometricUnlock : null,
        ),
      _Screen.vault => VaultPage(onLock: _lockVault, onVaultDeleted: _handleVaultDeleted),
    };
  }
}
