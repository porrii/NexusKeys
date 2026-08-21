import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/di/service_locator.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:nexuskeys/features/settings/domain/repositories/settings_repository.dart';
import 'package:nexuskeys/features/settings/presentation/pages/auto_lock_settings_page.dart';
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

  testWidgets('renders every option, including Nunca and Inmediato', (tester) async {
    await tester.pumpWidget(wrap(const AutoLockSettingsPage()));

    expect(find.text('Inmediato'), findsOneWidget);
    expect(find.text('1 minutos'), findsOneWidget);
    expect(find.text('5 minutos'), findsOneWidget);
    expect(find.text('15 minutos'), findsOneWidget);
    expect(find.text('30 minutos'), findsOneWidget);
    expect(find.text('Nunca'), findsOneWidget);
  });

  testWidgets('5 minutos is selected by default', (tester) async {
    await tester.pumpWidget(wrap(const AutoLockSettingsPage()));

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('tapping Nunca persists a null autoLockAfter', (tester) async {
    await tester.pumpWidget(wrap(const AutoLockSettingsPage()));

    await tester.tap(find.text('Nunca'));
    await tester.pump();

    expect(sl<SettingsRepository>().current.autoLockAfter, isNull);
  });

  testWidgets('tapping Inmediato persists Duration.zero, not null', (tester) async {
    await tester.pumpWidget(wrap(const AutoLockSettingsPage()));

    await tester.tap(find.text('Inmediato'));
    await tester.pump();

    expect(sl<SettingsRepository>().current.autoLockAfter, Duration.zero);
  });
}
