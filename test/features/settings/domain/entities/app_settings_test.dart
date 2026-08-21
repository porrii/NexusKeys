import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/features/settings/domain/entities/app_settings.dart';

void main() {
  group('formatAutoLockDuration', () {
    test('null is "Nunca"', () {
      expect(formatAutoLockDuration(null), 'Nunca');
    });

    test('zero is "Inmediato"', () {
      expect(formatAutoLockDuration(Duration.zero), 'Inmediato');
    });

    test('sub-hour durations are shown in minutes', () {
      expect(formatAutoLockDuration(const Duration(minutes: 15)), '15 minutos');
    });

    test('hour-scale durations are shown in hours', () {
      expect(formatAutoLockDuration(const Duration(hours: 2)), '2 horas');
    });
  });

  group('AppSettings', () {
    test('defaults() matches the mockup (5 minutos, Oscuro, lock on close on)', () {
      final defaults = AppSettings.defaults();

      expect(defaults.themeMode, AppThemeMode.dark);
      expect(defaults.autoLockAfter, const Duration(minutes: 5));
      expect(defaults.lockOnClose, isTrue);
      expect(defaults.biometricEnabled, isFalse);
    });

    test('copyWith overrides only the given fields', () {
      final changed = AppSettings.defaults().copyWith(themeMode: AppThemeMode.oled);

      expect(changed.themeMode, AppThemeMode.oled);
      expect(changed.autoLockAfter, AppSettings.defaults().autoLockAfter);
    });

    test('copyWith can set autoLockAfter to null ("Nunca") via the sentinel pattern', () {
      final changed = AppSettings.defaults().copyWith(autoLockAfter: null);

      expect(changed.autoLockAfter, isNull);
    });

    test('copyWith without touching autoLockAfter leaves it as-is', () {
      final withNoAutoLock = AppSettings.defaults().copyWith(autoLockAfter: null);
      final changed = withNoAutoLock.copyWith(lockOnClose: false);

      expect(changed.autoLockAfter, isNull);
    });

    test('two settings with identical fields are equal', () {
      expect(AppSettings.defaults(), AppSettings.defaults());
    });
  });
}
