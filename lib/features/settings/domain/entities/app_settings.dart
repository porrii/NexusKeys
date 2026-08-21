import 'package:equatable/equatable.dart';

/// The three looks offered on img/12_theme.png, plus following the OS.
enum AppThemeMode { light, dark, oled, system }

/// Auto-lock timing options shown on the "Bloqueo automático" picker.
/// `Duration.zero` means "Inmediato" (lock the instant the app leaves the
/// foreground); null means "Nunca" (auto-lock disabled).
const List<Duration?> autoLockOptions = [
  Duration.zero,
  Duration(minutes: 1),
  Duration(minutes: 5),
  Duration(minutes: 15),
  Duration(minutes: 30),
  null,
];

String formatAutoLockDuration(Duration? duration) {
  if (duration == null) return 'Nunca';
  if (duration == Duration.zero) return 'Inmediato';
  if (duration.inMinutes < 60) return '${duration.inMinutes} minutos';
  return '${duration.inHours} horas';
}

/// A snapshot of every user-configurable app setting.
class AppSettings extends Equatable {
  const AppSettings({
    required this.themeMode,
    required this.autoLockAfter,
    required this.lockOnClose,
    required this.biometricEnabled,
  });

  factory AppSettings.defaults() => const AppSettings(
        themeMode: AppThemeMode.dark,
        autoLockAfter: Duration(minutes: 5),
        lockOnClose: true,
        biometricEnabled: false,
      );

  final AppThemeMode themeMode;
  final Duration? autoLockAfter;
  final bool lockOnClose;
  final bool biometricEnabled;

  /// [autoLockAfter] is itself nullable ("Nunca"), so a plain `Duration?
  /// autoLockAfter` parameter couldn't tell "leave it as-is" apart from
  /// "set it to null" — [_unset] is the standard sentinel-object pattern
  /// for a nullable field in an otherwise ordinary copyWith.
  AppSettings copyWith({
    AppThemeMode? themeMode,
    Object? autoLockAfter = _unset,
    bool? lockOnClose,
    bool? biometricEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      autoLockAfter:
          identical(autoLockAfter, _unset) ? this.autoLockAfter : autoLockAfter as Duration?,
      lockOnClose: lockOnClose ?? this.lockOnClose,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }

  @override
  List<Object?> get props => [themeMode, autoLockAfter, lockOnClose, biometricEnabled];
}

class _Unset {
  const _Unset();
}

const _unset = _Unset();
