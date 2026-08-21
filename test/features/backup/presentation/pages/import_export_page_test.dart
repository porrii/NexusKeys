import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/database/vault_session.dart';
import 'package:nexuskeys/core/di/service_locator.dart';
import 'package:nexuskeys/core/security/crypto_service.dart';
import 'package:nexuskeys/core/security/crypto_service_impl.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:nexuskeys/features/backup/domain/services/backup_service.dart';
import 'package:nexuskeys/features/backup/presentation/pages/import_export_page.dart';

// The actual export/import buttons invoke package:file_selector's native
// platform channel, which isn't available under flutter test — these tests
// cover the screen's static content only. BackupService's own logic
// (round-trip, tamper/wrong-password rejection) is covered in
// backup_service_test.dart without going through any UI or file picker.
void main() {
  setUp(() {
    sl
      ..registerLazySingleton<CryptoService>(CryptoServiceImpl.new)
      ..registerLazySingleton(AuthLocalDataSource.new)
      ..registerLazySingleton(VaultSession.new)
      ..registerLazySingleton(
        () => BackupService(
          cryptoService: sl(),
          authLocalDataSource: sl(),
          vaultSession: sl(),
        ),
      );
  });

  tearDown(() async {
    await sl.reset();
  });

  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  testWidgets('renders every element from img/09_import_export.png', (tester) async {
    await tester.pumpWidget(wrap(const ImportExportPage()));

    expect(find.text('Importar / Exportar'), findsOneWidget);
    expect(find.text('EXPORTAR BÓVEDA'), findsOneWidget);
    expect(
      find.text('Exporta tu bóveda a un archivo cifrado para guardarlo de forma segura.'),
      findsOneWidget,
    );
    expect(find.text('Exportar'), findsOneWidget);
    expect(find.text('IMPORTAR BÓVEDA'), findsOneWidget);
    expect(
      find.text('Importa un archivo .nexus previamente exportado para restaurar tu bóveda.'),
      findsOneWidget,
    );
    expect(find.text('Importar'), findsOneWidget);
  });
}
