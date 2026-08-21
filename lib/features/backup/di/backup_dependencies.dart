import 'package:get_it/get_it.dart';

import '../../../core/database/vault_session.dart';
import '../../../core/security/crypto_service.dart';
import '../../auth/data/datasources/auth_local_data_source.dart';
import '../domain/services/backup_service.dart';

void configureBackupDependencies(GetIt sl) {
  sl.registerLazySingleton(
    () => BackupService(
      cryptoService: sl<CryptoService>(),
      authLocalDataSource: sl<AuthLocalDataSource>(),
      vaultSession: sl<VaultSession>(),
    ),
  );
}
