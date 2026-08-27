import 'package:flutter/material.dart';

/// Replaces the AppBar title for a page that can render either as its own
/// full screen (mobile, or pushed over the wide layout's sidebar) or
/// embedded directly in the wide layout's content area (img/13_tablet.png,
/// img/14_windows.png) — TagsPage, TrashPage and SettingsPage all reuse
/// this so the embedded form stays visually consistent across the three.
class EmbeddedSectionHeader extends StatelessWidget {
  const EmbeddedSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)),
      ),
    );
  }
}
