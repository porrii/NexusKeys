import 'package:get_it/get_it.dart';

import '../../features/auth/di/auth_dependencies.dart';
import '../../features/generator/di/generator_dependencies.dart';
import '../../features/vault/di/vault_dependencies.dart';
import '../database/vault_session.dart';

/// Global service locator. Each feature module registers its own
/// dependencies through a `configureXxxDependencies()` function called from
/// [setupServiceLocator], keeping features decoupled from one another.
final GetIt sl = GetIt.instance;

/// Wires up every feature module's dependencies. Called once from `main()`
/// before `runApp`.
Future<void> setupServiceLocator() async {
  // Core infrastructure shared by every feature.
  sl.registerLazySingleton(VaultSession.new);

  configureAuthDependencies(sl);
  configureVaultDependencies(sl);
  configureGeneratorDependencies(sl);
}
