import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/auth/presentation/pages/lock_screen_page.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.dark, home: child);
  }

  testWidgets('renders every element from img/01_lock.png', (tester) async {
    await tester.pumpWidget(wrap(const LockScreenPage()));

    expect(find.text('NexusKeys'), findsOneWidget);
    expect(find.text('Desbloquear bóveda'), findsOneWidget);
    expect(find.text('Desbloquear'), findsOneWidget);
    expect(find.text('Otras opciones'), findsOneWidget);
    expect(find.byIcon(Icons.fingerprint), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.hintText, 'Contraseña maestra');
    expect(field.obscureText, isTrue);
  });

  testWidgets('password visibility toggle switches the obscure icon', (tester) async {
    await tester.pumpWidget(wrap(const LockScreenPage()));

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('submitting the password field invokes onUnlock with its value', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      wrap(LockScreenPage(onUnlock: (value) => submitted = value)),
    );

    await tester.enterText(find.byType(TextField), 'correct-horse-battery-staple');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submitted, 'correct-horse-battery-staple');
  });

  testWidgets('the fingerprint icon and Otras opciones are hidden entirely when unavailable', (tester) async {
    await tester.pumpWidget(wrap(const LockScreenPage(biometricAvailable: false)));

    expect(find.byIcon(Icons.fingerprint), findsNothing);
    expect(find.text('Otras opciones'), findsNothing);
  });

  testWidgets('the fingerprint icon is disabled (but still visible) while unlocking', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(LockScreenPage(isUnlocking: true, onBiometricUnlock: () => tapped = true)),
    );

    final button = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.fingerprint));
    expect(button.onPressed, isNull);
    expect(tapped, isFalse);
  });
}
