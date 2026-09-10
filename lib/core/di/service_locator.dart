import 'package:get_it/get_it.dart';

import '../../features/auth/di/auth_dependencies.dart';
import '../../features/backup/di/backup_dependencies.dart';
import '../../features/generator/di/generator_dependencies.dart';
import '../../features/settings/di/settings_dependencies.dart';
import '../../features/vault/di/vault_dependencies.dart';
import '../database/vault_session.dart';

/// Service locator global. Cada módulo de feature registra sus propias
/// dependencias mediante una función `configureXxxDependencies()` que se
/// llama desde [setupServiceLocator], manteniendo las features
/// desacopladas entre sí.
final GetIt sl = GetIt.instance;

/// Conecta las dependencias de todos los módulos de feature. Se llama una
/// vez desde `main()` antes de `runApp`.
Future<void> setupServiceLocator() async {
  // Infraestructura común compartida por todas las features.
  sl.registerLazySingleton(VaultSession.new);

  configureAuthDependencies(sl);
  configureVaultDependencies(sl);
  configureGeneratorDependencies(sl);
  configureBackupDependencies(sl);
  await configureSettingsDependencies(sl);
}
