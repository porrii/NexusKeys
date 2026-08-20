import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item_type.dart';
import 'package:nexuskeys/features/vault/presentation/pages/item_details_page.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  // The details ListView (header + up to five field cards + the Editar/
  // Eliminar row) doesn't fit the default test surface, so the button row
  // never gets laid out and every finder for it comes back empty.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  VaultItem googleItem({bool favorite = true}) {
    final now = DateTime.now();
    return VaultItem(
      id: 1,
      type: VaultItemType.password,
      title: 'Google',
      username: 'ivan@gmail.com',
      password: 'S3cr3t!Password',
      url: 'https://accounts.google.com',
      notes: 'Cuenta principal de Google',
      category: 'Cuenta de Google',
      tags: const ['Email', 'Personal'],
      isFavorite: favorite,
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('renders every element from img/04_item_details.png', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(ItemDetailsPage(item: googleItem())));

    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Cuenta de Google'), findsOneWidget);
    expect(find.text('Usuario'), findsOneWidget);
    expect(find.text('ivan@gmail.com'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Sitio web'), findsOneWidget);
    expect(find.text('https://accounts.google.com'), findsOneWidget);
    expect(find.text('Notas'), findsOneWidget);
    expect(find.text('Cuenta principal de Google'), findsOneWidget);
    expect(find.text('Etiquetas'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
  });

  testWidgets('the password is masked until the reveal icon is tapped', (tester) async {
    await tester.pumpWidget(wrap(ItemDetailsPage(item: googleItem())));

    expect(find.text('S3cr3t!Password'), findsNothing);
    expect(find.textContaining('•'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(find.text('S3cr3t!Password'), findsOneWidget);
  });

  testWidgets('shows a strong-password indicator for a strong password', (tester) async {
    await tester.pumpWidget(wrap(ItemDetailsPage(item: googleItem())));

    expect(find.text('Fuerte'), findsOneWidget);
  });

  testWidgets('the favorite star updates immediately and reports the new value', (tester) async {
    bool? reported;
    await tester.pumpWidget(
      wrap(ItemDetailsPage(item: googleItem(favorite: false), onToggleFavorite: (v) => reported = v)),
    );

    expect(find.byIcon(Icons.star_border), findsOneWidget);

    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pump();

    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(reported, isTrue);
  });

  testWidgets('Editar awaits onEdit and refreshes the displayed item', (tester) async {
    useTallViewport(tester);
    final edited = googleItem().copyWith(title: 'Google Workspace');
    await tester.pumpWidget(
      wrap(ItemDetailsPage(item: googleItem(), onEdit: () async => edited)),
    );

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    expect(find.text('Google Workspace'), findsOneWidget);
  });

  testWidgets('Eliminar asks for confirmation before calling onDelete', (tester) async {
    useTallViewport(tester);
    var deleted = false;
    await tester.pumpWidget(wrap(ItemDetailsPage(item: googleItem(), onDelete: () => deleted = true)));

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(deleted, isFalse, reason: 'should wait for confirmation');

    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });

  testWidgets('cancelling the delete dialog does not call onDelete', (tester) async {
    useTallViewport(tester);
    var deleted = false;
    await tester.pumpWidget(wrap(ItemDetailsPage(item: googleItem(), onDelete: () => deleted = true)));

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(deleted, isFalse);
  });
}
