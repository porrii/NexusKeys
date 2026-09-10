import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// Selector de "Bloqueo automático" de img/08_settings.png — sin mockup
/// propio, con el estilo de la lista de opciones de [ThemeSettingsPage]
/// por coherencia.
class AutoLockSettingsPage extends StatefulWidget {
  const AutoLockSettingsPage({super.key, this.embedded = false});

  /// True cuando SettingsPage la renderiza en línea en el layout ancho en
  /// vez de empujarla como su propia ruta — se salta el Scaffold/AppBar,
  /// ya que el padre ya aporta una cabecera (con flecha de volver)
  /// alrededor.
  final bool embedded;

  @override
  State<AutoLockSettingsPage> createState() => _AutoLockSettingsPageState();
}

class _AutoLockSettingsPageState extends State<AutoLockSettingsPage> {
  final SettingsRepository _settings = sl<SettingsRepository>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _settings.current.autoLockAfter;

    final list = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final option in autoLockOptions) ...[
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: option == current ? AppColors.primary : theme.dividerColor),
            ),
            child: InkWell(
              onTap: () async {
                await _settings.setAutoLockAfter(option);
                if (mounted) setState(() {});
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(formatAutoLockDuration(option), style: theme.textTheme.bodyLarge),
                    ),
                    if (option == current)
                      const Icon(Icons.check_circle, color: AppColors.primary)
                    else
                      Icon(Icons.circle_outlined, color: theme.dividerColor),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );

    if (widget.embedded) return list;
    return Scaffold(
      appBar: AppBar(title: const Text('Bloqueo automático')),
      body: SafeArea(child: list),
    );
  }
}
