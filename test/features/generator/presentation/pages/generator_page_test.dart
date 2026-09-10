import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/di/service_locator.dart';
import 'package:nexuskeys/core/security/crypto_service.dart';
import 'package:nexuskeys/core/security/crypto_service_impl.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/generator/domain/services/password_generator_service.dart';
import 'package:nexuskeys/features/generator/presentation/pages/generator_page.dart';

void main() {
  setUp(() async {
    await sl.reset();
    sl.registerLazySingleton<CryptoService>(CryptoServiceImpl.new);
    sl.registerLazySingleton(() => PasswordGeneratorService(cryptoService: sl()));
  });

  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  // La lista completa de controles (tarjeta de contraseña, medidor de
  // fortaleza, slider, cinco interruptores, dos checkboxes, el botón) no
  // cabe en la superficie de test por defecto, así que nada por debajo del
  // pliegue llega a distribuirse.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('renders every element from img/06_generator.png', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const GeneratorPage()));

    expect(find.text('Generador'), findsOneWidget);
    expect(find.text('Fortaleza'), findsOneWidget);
    expect(find.text('Longitud'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
    expect(find.text('Mayúsculas (A-Z)'), findsOneWidget);
    expect(find.text('Minúsculas (a-z)'), findsOneWidget);
    expect(find.text('Números (0-9)'), findsOneWidget);
    expect(find.text('Símbolos (!@#\$%)'), findsOneWidget);
    expect(find.text('Excluir caracteres ambiguos'), findsOneWidget);
    expect(find.text('Excluir caracteres repetidos'), findsOneWidget);
    expect(find.text('Generar contraseña'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('starts with a 16-character password, per the default options', (tester) async {
    await tester.pumpWidget(wrap(const GeneratorPage()));

    final displayed = tester.widgetList<Text>(find.byType(Text)).firstWhere(
          (t) => t.style?.fontFamily == 'monospace',
        );
    expect(displayed.data, hasLength(16));
  });

  testWidgets('the refresh action produces a different password', (tester) async {
    await tester.pumpWidget(wrap(const GeneratorPage()));

    String currentPassword() => tester.widgetList<Text>(find.byType(Text)).firstWhere(
          (t) => t.style?.fontFamily == 'monospace',
        ).data!;

    final before = currentPassword();
    await tester.tap(find.byIcon(Icons.refresh).first);
    await tester.pump();

    expect(currentPassword(), isNot(before));
  });

  testWidgets('moving the length slider changes the displayed length and password length', (tester) async {
    await tester.pumpWidget(wrap(const GeneratorPage()));

    tester.widget<Slider>(find.byType(Slider)).onChanged!(32);
    await tester.pump();

    expect(find.text('32'), findsOneWidget);
    final displayed = tester.widgetList<Text>(find.byType(Text)).firstWhere(
          (t) => t.style?.fontFamily == 'monospace',
        );
    expect(displayed.data, hasLength(32));
  });

  testWidgets('turning off every character class disables the button and shows a warning', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap(const GeneratorPage()));

    for (final label in ['Mayúsculas (A-Z)', 'Minúsculas (a-z)', 'Números (0-9)', 'Símbolos (!@#\$%)']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }

    expect(find.text('Selecciona al menos un tipo de carácter'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });
}
