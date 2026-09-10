import 'package:equatable/equatable.dart';

/// Los tres aspectos que ofrece img/12_theme.png, más seguir al del SO.
enum AppThemeMode { light, dark, oled, system }

/// Opciones de tiempo del bloqueo automático que se muestran en el
/// selector de "Bloqueo automático". `Duration.zero` significa "Inmediato"
/// (bloquear en el instante en que la app deja el primer plano); null
/// significa "Nunca" (bloqueo automático desactivado).
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

/// Una instantánea de todos los ajustes de la app configurables por el
/// usuario.
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

  /// [autoLockAfter] es a su vez nullable ("Nunca"), así que un parámetro
  /// `Duration? autoLockAfter` normal no podría distinguir "déjalo como
  /// está" de "ponlo a null" — [_unset] es el patrón estándar de objeto
  /// centinela para un campo nullable en un copyWith por lo demás
  /// corriente.
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
