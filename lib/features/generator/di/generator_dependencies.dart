import 'package:get_it/get_it.dart';

import '../../../core/security/crypto_service.dart';
import '../domain/services/password_generator_service.dart';

void configureGeneratorDependencies(GetIt sl) {
  sl.registerLazySingleton(() => PasswordGeneratorService(cryptoService: sl<CryptoService>()));
}
