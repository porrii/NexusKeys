import 'package:get_it/get_it.dart';

import '../../../core/security/crypto_service.dart';
import '../../../core/security/crypto_service_impl.dart';
import '../data/datasources/auth_local_data_source.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';

/// Registers the auth feature's dependencies into [sl]. Called once from
/// [setupServiceLocator] during app startup.
void configureAuthDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<CryptoService>(CryptoServiceImpl.new)
    ..registerLazySingleton(AuthLocalDataSource.new)
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        cryptoService: sl(),
        localDataSource: sl(),
      ),
    );
}
