import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item.dart';
import 'package:nexuskeys/features/vault/domain/entities/vault_item_type.dart';
import 'package:nexuskeys/features/vault/presentation/pages/edit_vault_item_page.dart';

void main() {
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

  testWidgets('creating: has no delete button', (tester) async {
    await tester.pumpWidget(wrap(const EditVaultItemPage()));

    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('editing: pre-fills the form from the existing item', (tester) async {
    await tester.pumpWidget(wrap(EditVaultItemPage(existingItem: existing())));

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

  testWidgets('editing: the delete button asks for confirmation before calling onDelete', (tester) async {
    var deleted = false;
    await tester.pumpWidget(
      wrap(EditVaultItemPage(existingItem: existing(), onDelete: () => deleted = true)),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(deleted, isFalse, reason: 'should wait for confirmation');

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });

  testWidgets('editing: cancelling the delete dialog does not call onDelete', (tester) async {
    var deleted = false;
    await tester.pumpWidget(
      wrap(EditVaultItemPage(existingItem: existing(), onDelete: () => deleted = true)),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(deleted, isFalse);
  });
}
