import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/security/password_strength.dart';
import '../../../../core/widgets/segmented_strength_indicator.dart';
import '../../domain/entities/generator_options.dart';
import '../../domain/services/password_generator_service.dart';

/// Reproduce img/06_generator.png. "Pronunciables" se añade como un quinto
/// interruptor junto a Mayúsculas/Minúsculas/Números/Símbolos — no está en
/// esa captura concreta, pero lo exige explícitamente la sección Generador
/// de la especificación, y es el mismo estilo de control, así que no
/// introduce un lenguaje visual nuevo. Los bits de entropía y un tiempo
/// estimado de rotura se muestran como un pequeño texto bajo el medidor de
/// fortaleza por la misma razón: la especificación los pide explícitamente
/// ("Mostrar: Fortaleza, Entropía, Tiempo estimado"), es solo que el
/// mockup no tiene sitio para mostrar todos los detalles.
class GeneratorPage extends StatefulWidget {
  const GeneratorPage({super.key});

  @override
  State<GeneratorPage> createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  final PasswordGeneratorService _generator = sl<PasswordGeneratorService>();

  GeneratorOptions _options = GeneratorOptions.recommended();
  late String _password;

  @override
  void initState() {
    super.initState();
    _password = _generator.generate(_options);
  }

  void _regenerate() => setState(() => _password = _generator.generate(_options));

  void _updateOptions(GeneratorOptions Function(GeneratorOptions) update) {
    setState(() {
      _options = update(_options);
      _password = _generator.generate(_options);
    });
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _password));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contraseña copiada')),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disponible próximamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // El modo pronunciable alterna consonantes/vocales en vez de muestrear
    // uniformemente de un charset plano, así que no hay un único "tamaño
    // de charset" del que calcular entropía exacta — la inferencia por
    // clases de carácter de estimateEntropyBits es ahí la aproximación
    // honesta.
    final entropyBits = _options.pronounceable
        ? estimateEntropyBits(_password)
        : exactEntropyBits(length: _password.length, charsetSize: _generator.characterSetFor(_options).length);
    final strength = classifyEntropyBits(entropyBits);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generador'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _regenerate),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _password,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontFamily: 'monospace',
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.copy_outlined), onPressed: _copyToClipboard),
                    IconButton(icon: const Icon(Icons.refresh), onPressed: _regenerate),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SegmentedStrengthIndicator(strength: strength),
            const SizedBox(height: 6),
            Text(
              '${entropyBits.round()} bits de entropía · tardaría ${estimateCrackTime(entropyBits)} en romperse',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Longitud', style: theme.textTheme.bodyMedium),
              ],
            ),
            Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text('${_options.length}', style: theme.textTheme.bodyLarge),
                ),
                Expanded(
                  child: Slider(
                    value: _options.length.toDouble(),
                    min: GeneratorOptions.minLength.toDouble(),
                    max: GeneratorOptions.maxLength.toDouble(),
                    divisions: GeneratorOptions.maxLength - GeneratorOptions.minLength,
                    onChanged: (value) => _updateOptions((o) => o.copyWith(length: value.round())),
                  ),
                ),
                IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _showComingSoon),
              ],
            ),
            const SizedBox(height: 8),
            _ToggleRow(
              label: 'Mayúsculas (A-Z)',
              value: _options.useUppercase,
              onChanged: (v) => _updateOptions((o) => o.copyWith(useUppercase: v)),
            ),
            _ToggleRow(
              label: 'Minúsculas (a-z)',
              value: _options.useLowercase,
              onChanged: (v) => _updateOptions((o) => o.copyWith(useLowercase: v)),
            ),
            _ToggleRow(
              label: 'Números (0-9)',
              value: _options.useNumbers,
              onChanged: (v) => _updateOptions((o) => o.copyWith(useNumbers: v)),
            ),
            _ToggleRow(
              label: 'Símbolos (!@#\$%)',
              value: _options.useSymbols,
              onChanged: (v) => _updateOptions((o) => o.copyWith(useSymbols: v)),
            ),
            _ToggleRow(
              label: 'Pronunciables',
              value: _options.pronounceable,
              onChanged: (v) => _updateOptions((o) => o.copyWith(pronounceable: v)),
            ),
            const SizedBox(height: 8),
            _CheckboxRow(
              label: 'Excluir caracteres ambiguos',
              value: _options.excludeAmbiguous,
              onChanged: (v) => _updateOptions((o) => o.copyWith(excludeAmbiguous: v)),
            ),
            _CheckboxRow(
              label: 'Excluir caracteres repetidos',
              value: _options.excludeRepeated,
              onChanged: (v) => _updateOptions((o) => o.copyWith(excludeRepeated: v)),
            ),
            const SizedBox(height: 20),
            if (!_options.hasAnyCharacterClassSelected)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Selecciona al menos un tipo de carácter',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _options.hasAnyCharacterClassSelected || _options.pronounceable ? _regenerate : null,
                child: const Text('Generar contraseña'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _CheckboxRow extends StatelessWidget {
  const _CheckboxRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(label),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
    );
  }
}
