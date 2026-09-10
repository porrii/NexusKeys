import '../entities/app_settings.dart';

/// Ver el comentario de [VaultRepository] para saber por qué esto expone
/// un getter síncrono [current] junto a un stream [changes] normal (que no
/// reproduce) en vez de un único stream que intente reproducir su último
/// valor.
abstract interface class SettingsRepository {
  AppSettings get current;
  Stream<AppSettings> get changes;

  Future<void> setThemeMode(AppThemeMode mode);
  Future<void> setAutoLockAfter(Duration? duration);
  Future<void> setLockOnClose(bool value);
  Future<void> setBiometricEnabled(bool value);
}
