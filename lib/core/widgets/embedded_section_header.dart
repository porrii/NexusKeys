import 'package:flutter/material.dart';

/// Replaces the AppBar title for a page that can render either as its own
/// full screen (mobile, or pushed over the wide layout's sidebar) or
/// embedded directly in the wide layout's content area (img/13_tablet.png,
/// img/14_windows.png) — TagsPage, TrashPage and SettingsPage all reuse
/// this so the embedded form stays visually consistent across them.
///
/// [onBack] adds a leading back arrow, for a sub-page embedded a level
/// deeper (e.g. Ajustes' "Tema") that still needs a way back to its parent
/// list without a pushed route's default AppBar back button to do it —
/// omit it for a top-level sidebar destination, which has nothing to go
/// back *to*.
class EmbeddedSectionHeader extends StatelessWidget {
  const EmbeddedSectionHeader(this.title, {super.key, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)),
          ),
        ],
      ),
    );
  }
}
