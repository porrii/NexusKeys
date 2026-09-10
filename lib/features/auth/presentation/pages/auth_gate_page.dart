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

/// Decides which screen opens the app: [WelcomePage] if no master password
/// has been configured yet, [LockScreenPage] otherwise. Owns navigation
/// between every screen in the auth flow so each page itself stays a pure,
/// easily-testable presentation shell.
///
/// [welcome], [lock] and [vault] are swapped in place via [setState] rather
/// than pushed as separate routes — this widget lives for the whole app
/// session, so its `context` is never invalidated by a route transition the
/// way it would be if a callback captured the context of a page that had
/// since been popped or replaced. [CreateMasterPasswordPage] is the one
/// genuine sub-screen, reached with a normal push/pop since it has its own
/// back button.
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

  /// Set the moment the app leaves the foreground, so [didChangeAppLifecycleState]
  /// can tell on resume how long it was away — that's what "Bloqueo automático"
  /// actually measures against. Cleared on resume.
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

  /// "Bloquear al cerrar" and "Bloqueo automático" (Ajustes > SEGURIDAD) were
  /// both persisted settings with nothing anywhere actually enforcing them —
  /// this is that enforcement. Only matters while the vault is unlocked;
  /// there's nothing to protect on the welcome/lock/loading screens.
  ///
  /// "Bloquear al cerrar" locks the instant the app leaves the foreground,
  /// regardless of how briefly - it doesn't wait to see if you come back.
  /// "Bloqueo automático" is the gentler alternative for when that's off: it
  /// only locks once you've actually been away for at least that long,
  /// checked when you return rather than via a background timer (the vault's
  /// contents aren't on screen while backgrounded either way, so checking on
  /// resume - before anything is shown again - is enough).
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
      // Resolved separately, after the lock screen is already on screen —
      // see _refreshBiometricAvailability's doc comment for why.
      _biometricAvailable = false;
    });
    if (initialized) unawaited(_refreshBiometricAvailability());
  }

  /// Whether to show the fingerprint icon on the lock screen — deliberately
  /// checked *after* [_checkVaultStatus] has already put the lock screen on
  /// screen, not as part of it. [BiometricService.isDeviceSupported] calls
  /// into the platform's biometric APIs, and on at least one real device
  /// that alone was enough to surface a native biometric prompt before
  /// NexusKeys' own lock screen had even painted — asking the user to
  /// authenticate before they had chosen to unlock at all. Running this
  /// after the fact means the lock screen, not a biometric prompt, is
  /// always what greets you first.
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
        // setupMasterPassword only fails on unexpected storage errors —
        // surface it rather than silently discarding it.
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
  }

  Future<void> _handleBiometricUnlock() async {
    final vaultKey = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => const BiometricPromptPage()),
    );
    if (vaultKey == null || !mounted) return;

    await _vaultSession.unlock(vaultKey);
    wipe(vaultKey);
    await sl<VaultRepository>().reload();
    if (!mounted) return;
    setState(() => _screen = _Screen.vault);
  }

  void _lockVault() {
    _vaultSession.lock();
    setState(() {
      _screen = _Screen.lock;
      _lockScreenError = null;
    });
    // Re-check in case biometric unlock was just enabled/disabled from
    // Settings during this session — _biometricAvailable was only computed
    // once, at cold start.
    _checkVaultStatus();
  }

  /// The vault (auth header + database file) was just erased from
  /// Settings' "Eliminar bóveda permanentemente" — there's nothing left to
  /// unlock, so this goes straight to [WelcomePage] rather than the lock
  /// screen [_lockVault] would show.
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
            // A vault now exists where there wasn't one — re-check rather
            // than assuming .lock, in case the import itself failed to
            // leave a well-formed auth header.
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
