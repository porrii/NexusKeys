import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/di/service_locator.dart';
import 'package:nexuskeys/core/security/crypto_service.dart';
import 'package:nexuskeys/core/security/crypto_service_impl.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/generator/domain/services/password_generator_service.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item_type.dart';
import 'package:nexuskeys/features/vault/domain/repositories/vault_repository.dart';
import 'package:nexuskeys/features/vault/presentation/pages/edit_vault_item_page.dart';

/// Minimal fake — only needed because EditVaultItemPage reads
/// currentItems for the Etiquetas autocomplete suggestions. None of these
/// tests exercise that suggestion list itself.
class _EmptyVaultRepository implements VaultRepository {
  @override
  List<VaultItem> currentItems = const [];

  @override
  List<VaultItem> currentTrash = const [];

  @override
  Stream<List<VaultItem>> get itemsStream => const Stream.empty();

  @override
  Stream<List<VaultItem>> get trashStream => const Stream.empty();

  @override
  Future<VaultItem> create(VaultItem draft) async => draft;

  @override
  Future<void> update(VaultItem item) async {}

  @override
  Future<void> setFavorite(int id, bool isFavorite) async {}

  @override
  Future<void> moveToTrash(int id) async {}

  @override
  Future<void> restoreFromTrash(int id) async {}

  @override
  Future<void> deletePermanently(int id) async {}

  @override
  Future<void> reload() async {}

  @override
  void dispose() {}
}

void main() {
  setUp(() async {
    await sl.reset();
    sl.registerLazySingleton<CryptoService>(CryptoServiceImpl.new);
    sl.registerLazySingleton(() => PasswordGeneratorService(cryptoService: sl()));
    sl.registerSingleton<VaultRepository>(_EmptyVaultRepository());
  });

  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  VaultItem existing() {
    final now = DateTime.now();
    return VaultItem(
      id: 3,
      type: VaultItemType.password,
      title: 'GitHub',
      username: 'ivan_dev',
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('renders every field from img/05_new_item.png', (tester) async {
    await tester.pumpWidget(wrap(const EditVaultItemPage()));

    expect(find.text('Nuevo elemento'), findsOneWidget);
    expect(find.widgetWithText(DropdownButtonFormField<VaultItemType>, 'Tipo'), findsOneWidget);
    expect(find.text('Ej. Spotify'), findsOneWidget);
    expect(find.text('Ej. usuario@email.com'), findsOneWidget);
    expect(find.text('Generar contraseña'), findsOneWidget);
    expect(find.text('https://ejemplo.com'), findsOneWidget);
    expect(find.text('Carpeta'), findsOneWidget);
    expect(find.text('Sin carpeta'), findsOneWidget);
    expect(find.text('Separadas por comas'), findsOneWidget);
    expect(find.text('Notas adicionales'), findsOneWidget);
  });

  testWidgets('creating: rejects an empty title', (tester) async {
    VaultItem? saved;
    await tester.pumpWidget(wrap(EditVaultItemPage(onSave: (item) => saved = item)));

    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();

    expect(find.text('El título es obligatorio'), findsOneWidget);
    expect(saved, isNull);
  });

  testWidgets('creating: submits a VaultItem built from the form fields', (tester) async {
    VaultItem? saved;
    await tester.pumpWidget(wrap(EditVaultItemPage(onSave: (item) => saved = item)));

    await tester.enterText(find.widgetWithText(TextField, 'Título'), 'GitHub');
    await tester.enterText(find.widgetWithText(TextField, 'Usuario'), 'ivan_dev');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.title, 'GitHub');
    expect(saved!.username, 'ivan_dev');
    expect(saved!.id, isNull);
  });

  testWidgets('the inline generate button fills in a 16-character password', (tester) async {
    await tester.pumpWidget(wrap(const EditVaultItemPage()));

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    final field = tester.widget<TextField>(
      find.ancestor(of: find.byIcon(Icons.refresh), matching: find.byType(TextField)),
    );
    expect(field.controller!.text, hasLength(16));
  });

  testWidgets('editing: pre-fills the form from the existing item', (tester) async {
    await tester.pumpWidget(wrap(EditVaultItemPage(existingItem: existing())));

    expect(find.text('Editar elemento'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('ivan_dev'), findsOneWidget);
  });

  testWidgets('editing: keeps the original id and createdAt on save', (tester) async {
    VaultItem? saved;
    final original = existing();
    await tester.pumpWidget(
      wrap(EditVaultItemPage(existingItem: original, onSave: (item) => saved = item)),
    );

    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();

    expect(saved!.id, original.id);
    expect(saved!.createdAt, original.createdAt);
  });
}
