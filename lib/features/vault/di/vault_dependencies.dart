import 'package:get_it/get_it.dart';

import '../data/datasources/vault_local_data_source.dart';
import '../data/repositories/vault_repository_impl.dart';
import '../domain/repositories/vault_repository.dart';

/// Registra las dependencias de la feature de la bóveda en [sl].
///
/// [VaultRepository] es un singleton perezoso, así que no se construye de
/// verdad hasta que algo lee por primera vez `sl<VaultRepository>()` — lo
/// que, por cómo está construido el flujo de autenticación, solo pasa
/// después de un desbloqueo correcto. Su constructor consulta la base de
/// datos de inmediato, así que este orden importa: tocarlo mientras la
/// bóveda está bloqueada lanza una excepción (ver [VaultSession.database]).
void configureVaultDependencies(GetIt sl) {
  sl
    ..registerLazySingleton(() => VaultLocalDataSource(vaultSession: sl()))
    ..registerLazySingleton<VaultRepository>(
      () => VaultRepositoryImpl(dataSource: sl()),
    );
}
