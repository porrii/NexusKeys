import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/auth/presentation/pages/create_master_password_page.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  testWidgets('rejects a password shorter than the minimum length', (tester) async {
    String? created;
    await tester.pumpWidget(wrap(CreateMasterPasswordPage(onCreate: (p) => created = p)));

    await tester.enterText(find.byType(TextField).first, 'short');
    await tester.enterText(find.byType(TextField).last, 'short');
    await tester.tap(find.text('Crear bóveda'));
    await tester.pump();

    expect(find.textContaining('al menos'), findsOneWidget);
    expect(created, isNull);
  });

  testWidgets('rejects mismatched passwords', (tester) async {
    String? created;
    await tester.pumpWidget(wrap(CreateMasterPasswordPage(onCreate: (p) => created = p)));

    await tester.enterText(find.byType(TextField).first, 'a-strong-password');
    await tester.enterText(find.byType(TextField).last, 'a-different-password');
    await tester.tap(find.text('Crear bóveda'));
    await tester.pump();

    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    expect(created, isNull);
  });

  testWidgets('accepts matching passwords at or above the minimum length', (tester) async {
    String? created;
    await tester.pumpWidget(wrap(CreateMasterPasswordPage(onCreate: (p) => created = p)));

    await tester.enterText(find.byType(TextField).first, 'a-strong-password');
    await tester.enterText(find.byType(TextField).last, 'a-strong-password');
    await tester.tap(find.text('Crear bóveda'));
    await tester.pump();

    expect(created, 'a-strong-password');
  });
}
