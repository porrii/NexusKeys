import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:nexuskeys/features/settings/domain/entities/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SettingsRepositoryImpl> makeRepository([Map<String, Object>? initial]) async {
    SharedPreferences.setMockInitialValues(initial ?? {});
    return SettingsRepositoryImpl(preferences: await SharedPreferences.getInstance());
  }

  test('current is AppSettings.defaults() on first run', () async {
    final repository = await makeRepository();
    expect(repository.current, AppSettings.defaults());
  });

  test('setThemeMode persists and updates current', () async {
    final repository = await makeRepository();

    await repository.setThemeMode(AppThemeMode.oled);

    expect(repository.current.themeMode, AppThemeMode.oled);
  });

  test('a new repository instance reads back a persisted theme mode', () async {
    SharedPreferences.setMockInitialValues({'settings.themeMode': 'oled'});
    final repository = SettingsRepositoryImpl(preferences: await SharedPreferences.getInstance());

    expect(repository.current.themeMode, AppThemeMode.oled);
  });

  test('setAutoLockAfter persists "Nunca" (null) correctly', () async {
    final repository = await makeRepository();

    await repository.setAutoLockAfter(null);
    expect(repository.current.autoLockAfter, isNull);

    SharedPreferences.setMockInitialValues({'settings.autoLockMinutes': -1});
    final reloaded = SettingsRepositoryImpl(preferences: await SharedPreferences.getInstance());
    expect(reloaded.current.autoLockAfter, isNull);
  });

  test('setAutoLockAfter persists "Inmediato" (zero) as distinct from "Nunca"', () async {
    final repository = await makeRepository();

    await repository.setAutoLockAfter(Duration.zero);

    expect(repository.current.autoLockAfter, Duration.zero);
    expect(repository.current.autoLockAfter, isNot(isNull));
  });

  test('setLockOnClose persists and updates current', () async {
    final repository = await makeRepository();

    await repository.setLockOnClose(false);

    expect(repository.current.lockOnClose, isFalse);
  });

  test('setBiometricEnabled persists and updates current', () async {
    final repository = await makeRepository();

    await repository.setBiometricEnabled(true);

    expect(repository.current.biometricEnabled, isTrue);
  });

  test('changes emits the updated settings after every setter', () async {
    final repository = await makeRepository();
    final emissions = <AppThemeMode>[];
    final sub = repository.changes.listen((s) => emissions.add(s.themeMode));
    addTearDown(sub.cancel);

    await repository.setThemeMode(AppThemeMode.light);
    await repository.setThemeMode(AppThemeMode.oled);
    // Broadcast stream delivery is scheduled via microtask, not synchronous
    // with .add() — flush the queue before asserting on what arrived.
    await Future<void>.delayed(Duration.zero);

    expect(emissions, [AppThemeMode.light, AppThemeMode.oled]);
  });
}
