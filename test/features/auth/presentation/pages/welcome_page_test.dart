import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/auth/presentation/pages/welcome_page.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  testWidgets('renders every element from img/02_welcome.png', (tester) async {
    await tester.pumpWidget(wrap(const WelcomePage()));

    expect(find.text('NexusKeys'), findsOneWidget);
    expect(find.textContaining('100% offline y segura'), findsOneWidget);
    expect(find.text('Sin conexión a internet'), findsOneWidget);
    expect(find.text('Tus datos, solo tuyos'), findsOneWidget);
    expect(find.text('Cifrado de extremo a extremo'), findsOneWidget);
    expect(find.text('Crear nueva bóveda'), findsOneWidget);
    expect(find.text('Abrir bóveda existente'), findsOneWidget);
  });

  testWidgets('invokes onCreateVault when the primary button is tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(WelcomePage(onCreateVault: () => tapped = true)));

    await tester.tap(find.text('Crear nueva bóveda'));

    expect(tapped, isTrue);
  });

  testWidgets('invokes onOpenExistingVault when the text button is tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(WelcomePage(onOpenExistingVault: () => tapped = true)));

    await tester.tap(find.text('Abrir bóveda existente'));

    expect(tapped, isTrue);
  });
}
