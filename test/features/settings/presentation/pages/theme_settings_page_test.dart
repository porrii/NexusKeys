import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/di/service_locator.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:nexuskeys/features/settings/domain/entities/app_settings.dart';
import 'package:nexuskeys/features/settings/domain/repositories/settings_repository.dart';
import 'package:nexuskeys/features/settings/presentation/pages/theme_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    await sl.reset();
    SharedPreferences.setMockInitialValues({});
    sl.registerSingleton<SettingsRepository>(
      SettingsRepositoryImpl(preferences: await SharedPreferences.getInstance()),
    );
  });

  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

  testWidgets('renders every option from img/12_theme.png', (tester) async {
    await tester.pumpWidget(wrap(const ThemeSettingsPage()));

    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Oscuro'), findsOneWidget);
    expect(find.text('OLED'), findsOneWidget);
    expect(find.text('Seguir sistema'), findsOneWidget);
  });

  testWidgets('Oscuro is selected by default, matching AppSettings.defaults()', (tester) async {
    await tester.pumpWidget(wrap(const ThemeSettingsPage()));

    // Exactly one filled check_circle (the selected row); the rest are
    // outline circles.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('tapping an option persists it to SettingsRepository', (tester) async {
    await tester.pumpWidget(wrap(const ThemeSettingsPage()));

    await tester.tap(find.text('OLED'));
    await tester.pump();

    expect(sl<SettingsRepository>().current.themeMode, AppThemeMode.oled);
  });
}
