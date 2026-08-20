import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A single row in the vault list — reproduces the item rows in
/// img/03_vault.png: a colored avatar, title, subtitle, and either a
/// favorite star or a chevron on the trailing edge.
///
/// The reference mockup's sample items use real brand logos (Google,
/// GitHub, YouTube...). Those aren't assets this project has a license to
/// bundle, so real items fall back to a letter avatar tinted with the
/// item's own `color` field — the same "Color/Icono" every vault item
/// stores per the spec — which keeps the layout identical without
/// fabricating trademarked artwork.
class VaultItemTile extends StatelessWidget {
  const VaultItemTile({
    required this.title,
    required this.subtitle,
    required this.avatarColor,
    this.isFavorite = false,
    this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final Color avatarColor;
  final bool isFavorite;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatarColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  title.isEmpty ? '?' : title[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              isFavorite
                  ? const Icon(Icons.star, color: AppColors.warning)
                  : Icon(Icons.chevron_right, color: theme.textTheme.bodyMedium?.color),
            ],
          ),
        ),
      ),
    );
  }
}
