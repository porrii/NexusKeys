import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// "Idioma" from img/08_settings.png. The spec asks for the app to be
/// "prepared for internationalization" without requiring full multi-locale
/// support yet — this shows the one real option (Español) rather than a
/// bare "coming soon" stub, since there genuinely is a current setting to
/// display, it just isn't changeable to anything else yet.
class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key, this.embedded = false});

  /// True when SettingsPage renders this inline in the wide layout instead
  /// of pushing it as its own route — skips the Scaffold/AppBar, since the
  /// parent already supplies a header (with a back arrow) around it.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // A ListView, not a lone Card centered/stretched in the body: with just
    // one language there's nothing to scroll, but sizing itself to content
    // (as ThemeSettingsPage's option list also does) keeps this from
    // stretching to fill the whole panel the way a bare Card would when
    // this renders embedded inside an Expanded — same fix either way, one
    // language or several.
    final list = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
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
      ],
    );

    if (embedded) return list;
    return Scaffold(
      appBar: AppBar(title: const Text('Idioma')),
      body: SafeArea(child: list),
    );
  }
}
