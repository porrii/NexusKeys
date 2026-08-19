import 'package:flutter/material.dart';

import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/lock_screen_page.dart';

// cryptography_flutter's native acceleration (Android/iOS/macOS) is
// registered automatically by Flutter — no manual enable() call needed,
// just the dependency in pubspec.yaml.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  runApp(const NexusKeysApp());
}

class NexusKeysApp extends StatelessWidget {
  const NexusKeysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NexusKeys',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const LockScreenPage(),
    );
  }
}
