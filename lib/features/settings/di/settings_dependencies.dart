import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/settings_repository_impl.dart';
import '../domain/repositories/settings_repository.dart';

/// Registers [SettingsRepository]. Unlike most other `configureXDependencies`
/// functions, this one is `async`: [SharedPreferences.getInstance] has to
/// complete before there's anything to hand out, so [SettingsRepository] is
/// registered as a ready-made singleton instance rather than a lazy
/// factory — nothing needs it before `runApp`, but nothing should have to
/// await for it either once the app is running.
Future<void> configureSettingsDependencies(GetIt sl) async {
  final preferences = await SharedPreferences.getInstance();
  sl.registerSingleton<SettingsRepository>(
    SettingsRepositoryImpl(preferences: preferences),
  );
}
