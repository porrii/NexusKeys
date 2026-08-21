import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/di/service_locator.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:nexuskeys/features/settings/domain/repositories/settings_repository.dart';
import 'package:nexuskeys/features/settings/presentation/pages/settings_page.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item.dart';
import 'package:nexuskeys/features/vault/domain/repositories/vault_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal fake — SettingsPage only needs a VaultRepository registered
/// because navigating to "Papelera" pushes TrashPage, which reads one.
/// None of these tests exercise trash behaviour itself (that's
/// trash_page_test.dart's job), so every method here is a bare stub.
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
    SharedPreferences.setMockInitialValues({});
    sl.registerSingleton<SettingsRepository>(
      SettingsRepositoryImpl(preferences: await SharedPreferences.getInstance()),
    );
    sl.registerSingleton<VaultRepository>(_EmptyVaultRepository());
  });

  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  // The full two-section list doesn't fit the default test surface.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('renders every row from img/08_settings.png', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    expect(find.text('SEGURIDAD'), findsOneWidget);
    expect(find.text('Bloqueo automático'), findsOneWidget);
    expect(find.text('5 minutos'), findsOneWidget);
    expect(find.text('Cambiar contraseña maestra'), findsOneWidget);
    expect(find.text('Autenticación biométrica'), findsOneWidget);
    expect(find.text('Desactivada'), findsOneWidget);
    expect(find.text('Bloquear al cerrar'), findsOneWidget);
    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Oscuro'), findsOneWidget);
    expect(find.text('Idioma'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);
    expect(find.text('Gestionar categorías'), findsOneWidget);
    expect(find.text('Papelera'), findsOneWidget);
  });

  testWidgets('Bloquear al cerrar starts on, per the mockup', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isTrue);
  });

  testWidgets('toggling Bloquear al cerrar persists the change', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(sl<SettingsRepository>().current.lockOnClose, isFalse);
  });

  testWidgets('Tema navigates to the theme picker and reflects a change back', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('Tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OLED'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('OLED'), findsOneWidget);
  });

  testWidgets('Papelera opens the trash screen', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('Papelera'));
    await tester.pumpAndSettle();

    expect(find.text('La papelera está vacía'), findsOneWidget);
  });

  testWidgets('Autenticación biométrica shows a coming-soon message', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('Autenticación biométrica'));
    await tester.pump();

    expect(find.text('Disponible próximamente'), findsOneWidget);
  });

  testWidgets('Gestionar categorías shows a coming-soon message', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const SettingsPage()));

    await tester.tap(find.text('Gestionar categorías'));
    await tester.pump();

    expect(find.text('Disponible próximamente'), findsOneWidget);
  });
}
