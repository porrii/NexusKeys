import 'package:flutter/material.dart';

import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/auth_gate_page.dart';
import 'features/settings/domain/entities/app_settings.dart';
import 'features/settings/domain/repositories/settings_repository.dart';

// cryptography_flutter's native acceleration (Android/iOS/macOS) is
// registered automatically by Flutter — no manual enable() call needed,
// just the dependency in pubspec.yaml.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  runApp(const NexusKeysApp());
}

class NexusKeysApp extends StatefulWidget {
  const NexusKeysApp({super.key});

  @override
  State<NexusKeysApp> createState() => _NexusKeysAppState();
}

class _NexusKeysAppState extends State<NexusKeysApp> with WidgetsBindingObserver {
  final SettingsRepository _settings = sl<SettingsRepository>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // "Seguir sistema" needs a rebuild when the OS switches light/dark
    // outside the app's own settings.
    if (_settings.current.themeMode == AppThemeMode.system) setState(() {});
  }

  ThemeData _resolveTheme(AppThemeMode mode) {
    final effectiveMode = mode == AppThemeMode.system
        ? (WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark
            ? AppThemeMode.dark
            : AppThemeMode.light)
        : mode;
    return switch (effectiveMode) {
      AppThemeMode.light => AppTheme.light,
      AppThemeMode.dark => AppTheme.dark,
      AppThemeMode.oled => AppTheme.oled,
      AppThemeMode.system => AppTheme.dark, // unreachable, effectiveMode never system
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppSettings>(
      initialData: _settings.current,
      stream: _settings.changes,
      builder: (context, snapshot) {
        final themeMode = (snapshot.data ?? AppSettings.defaults()).themeMode;
        return MaterialApp(
          title: 'NexusKeys',
          debugShowCheckedModeBanner: false,
          theme: _resolveTheme(themeMode),
          home: const AuthGatePage(),
        );
      },
    );
  }
}
