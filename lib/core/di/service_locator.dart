import 'package:get_it/get_it.dart';

import '../../features/auth/di/auth_dependencies.dart';

/// Global service locator. Each feature module registers its own
/// dependencies through a `configureXxxDependencies()` function called from
/// [setupServiceLocator], keeping features decoupled from one another.
final GetIt sl = GetIt.instance;

/// Wires up every feature module's dependencies. Called once from `main()`
/// before `runApp`.
Future<void> setupServiceLocator() async {
  configureAuthDependencies(sl);
}
