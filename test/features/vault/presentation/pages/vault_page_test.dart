import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/vault/presentation/pages/vault_page.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  // ListView.builder only builds items within the viewport, and the default
  // test surface is too short to fit all six sample rows below the app bar,
  // search field and filter chips. A taller viewport lets the "every
  // element is present" assertions check the whole list without scrolling.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('renders every element from img/03_vault.png', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const VaultPage()));

    expect(find.text('NexusKeys'), findsOneWidget);
    expect(find.text('Buscar en la bóveda'), findsOneWidget);
    expect(find.text('Todas'), findsOneWidget);
    expect(find.text('Favoritos'), findsOneWidget);
    expect(find.text('Recientes'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Tarjeta Banco'), findsOneWidget);
    expect(find.text('Correo Pro'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Bóveda'), findsOneWidget);
    expect(find.text('Generador'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
  });

  testWidgets('only Google (the sample favorite) shows a star', (tester) async {
    await tester.pumpWidget(wrap(const VaultPage()));

    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('the Favoritos chip filters the list down to favorite items only', (tester) async {
    await tester.pumpWidget(wrap(const VaultPage()));

    await tester.tap(find.text('Favoritos'));
    await tester.pumpAndSettle();

    expect(find.text('Google'), findsOneWidget);
    expect(find.text('GitHub'), findsNothing);
    expect(find.text('Netflix'), findsNothing);
  });

  testWidgets('the drawer\'s "Bloquear bóveda" entry calls onLock', (tester) async {
    var locked = false;
    await tester.pumpWidget(wrap(VaultPage(onLock: () => locked = true)));

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bloquear bóveda'));
    await tester.pumpAndSettle();

    expect(locked, isTrue);
  });

  testWidgets('tapping Generador or Ajustes does not call onLock', (tester) async {
    var locked = false;
    await tester.pumpWidget(wrap(VaultPage(onLock: () => locked = true)));

    await tester.tap(find.text('Generador'));
    await tester.pump();

    expect(locked, isFalse);
    expect(find.text('Disponible próximamente'), findsOneWidget);
  });
}
