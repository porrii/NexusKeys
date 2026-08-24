import 'package:get_it/get_it.dart';

import '../../../core/database/vault_session.dart';
import '../data/datasources/category_local_data_source.dart';
import '../data/datasources/vault_local_data_source.dart';
import '../data/repositories/category_repository_impl.dart';
import '../data/repositories/vault_repository_impl.dart';
import '../domain/repositories/category_repository.dart';
import '../domain/repositories/vault_repository.dart';

/// Registers the vault feature's dependencies into [sl].
///
/// [VaultRepository] is a lazy singleton, so it isn't actually constructed
/// until something first reads `sl<VaultRepository>()` — which, by the auth
/// flow's construction, only ever happens after a successful unlock. Its
/// constructor queries the database immediately, so this ordering matters:
/// touching it while the vault is locked throws (see [VaultSession.database]).
void configureVaultDependencies(GetIt sl) {
  sl
    ..registerLazySingleton(() => VaultLocalDataSource(vaultSession: sl()))
    ..registerLazySingleton<VaultRepository>(
      () => VaultRepositoryImpl(dataSource: sl()),
    )
    ..registerLazySingleton(() => CategoryLocalDataSource(vaultSession: sl()))
    ..registerLazySingleton<CategoryRepository>(
      () => CategoryRepositoryImpl(dataSource: sl()),
    );
}
