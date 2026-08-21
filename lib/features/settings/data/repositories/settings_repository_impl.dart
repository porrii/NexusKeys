import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({required SharedPreferences preferences}) : _prefs = preferences {
    current = _load();
  }

  static const _themeModeKey = 'settings.themeMode';

  /// Minutes as an int; 0 means "Inmediato" and -1 means "Nunca" (null).
  static const _autoLockMinutesKey = 'settings.autoLockMinutes';
  static const _lockOnCloseKey = 'settings.lockOnClose';
  static const _biometricEnabledKey = 'settings.biometricEnabled';

  final SharedPreferences _prefs;
  final _controller = StreamController<AppSettings>.broadcast();

  @override
  late AppSettings current;

  @override
  Stream<AppSettings> get changes => _controller.stream;

  AppSettings _load() {
    final defaults = AppSettings.defaults();

    final themeModeName = _prefs.getString(_themeModeKey);
    final themeMode = AppThemeMode.values.firstWhere(
      (m) => m.name == themeModeName,
      orElse: () => defaults.themeMode,
    );

    final autoLockMinutes = _prefs.getInt(_autoLockMinutesKey);
    final Duration? autoLockAfter = switch (autoLockMinutes) {
      null => defaults.autoLockAfter,
      -1 => null,
      final minutes => Duration(minutes: minutes),
    };

    return AppSettings(
      themeMode: themeMode,
      autoLockAfter: autoLockAfter,
      lockOnClose: _prefs.getBool(_lockOnCloseKey) ?? defaults.lockOnClose,
      biometricEnabled: _prefs.getBool(_biometricEnabledKey) ?? defaults.biometricEnabled,
    );
  }

  void _emit(AppSettings settings) {
    current = settings;
    _controller.add(settings);
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    await _prefs.setString(_themeModeKey, mode.name);
    _emit(current.copyWith(themeMode: mode));
  }

  @override
  Future<void> setAutoLockAfter(Duration? duration) async {
    await _prefs.setInt(_autoLockMinutesKey, duration?.inMinutes ?? -1);
    _emit(current.copyWith(autoLockAfter: duration));
  }

  @override
  Future<void> setLockOnClose(bool value) async {
    await _prefs.setBool(_lockOnCloseKey, value);
    _emit(current.copyWith(lockOnClose: value));
  }

  @override
  Future<void> setBiometricEnabled(bool value) async {
    await _prefs.setBool(_biometricEnabledKey, value);
    _emit(current.copyWith(biometricEnabled: value));
  }

  void dispose() => _controller.close();
}
