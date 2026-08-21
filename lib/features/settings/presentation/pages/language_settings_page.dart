import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// "Idioma" from img/08_settings.png. The spec asks for the app to be
/// "prepared for internationalization" without requiring full multi-locale
/// support yet — this shows the one real option (Español) rather than a
/// bare "coming soon" stub, since there genuinely is a current setting to
/// display, it just isn't changeable to anything else yet.
class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Idioma')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.primary),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(child: Text('Español', style: theme.textTheme.bodyLarge)),
                  const Icon(Icons.check_circle, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
