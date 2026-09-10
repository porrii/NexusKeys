import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/settings_repository_impl.dart';
import '../domain/repositories/settings_repository.dart';

/// Registra [SettingsRepository]. A diferencia de la mayoría de las otras
/// funciones `configureXDependencies`, esta es `async`:
/// [SharedPreferences.getInstance] tiene que completarse antes de que haya
/// algo que entregar, así que [SettingsRepository] se registra como una
/// instancia singleton ya lista en vez de como una factoría perezosa —
/// nada lo necesita antes de `runApp`, pero tampoco nada debería tener que
/// esperarlo una vez la app está en marcha.
Future<void> configureSettingsDependencies(GetIt sl) async {
  final preferences = await SharedPreferences.getInstance();
  sl.registerSingleton<SettingsRepository>(
    SettingsRepositoryImpl(preferences: preferences),
  );
}
