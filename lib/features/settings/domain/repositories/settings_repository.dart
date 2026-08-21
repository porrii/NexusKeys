import '../entities/app_settings.dart';

/// See [VaultRepository]'s doc comment for why this exposes a synchronous
/// [current] getter alongside a plain (non-replaying) [changes] stream
/// rather than one stream that tries to replay its latest value.
abstract interface class SettingsRepository {
  AppSettings get current;
  Stream<AppSettings> get changes;

  Future<void> setThemeMode(AppThemeMode mode);
  Future<void> setAutoLockAfter(Duration? duration);
  Future<void> setLockOnClose(bool value);
  Future<void> setBiometricEnabled(bool value);
}
