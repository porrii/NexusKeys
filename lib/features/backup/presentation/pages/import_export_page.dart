import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/widgets/app_password_field.dart';
import '../../domain/services/backup_service.dart';

/// Reproduce img/09_import_export.png. Se reutiliza tanto desde Ajustes
/// (exportar un backup, o restaurar uno sobre la bóveda actual) como desde
/// el "Abrir bóveda existente" de img/02_welcome.png (importar para
/// arrancar una bóveda en una instalación nueva) — [onImportComplete] deja
/// que cada llamante decida qué pasa tras una restauración correcta, ya
/// que difiere: Ajustes tiene que volver a la pantalla de bloqueo (la
/// cabecera de autenticación se acaba de reemplazar), y el flujo de
/// bienvenida tiene que desbloquear directo.
class ImportExportPage extends StatefulWidget {
  const ImportExportPage({
    super.key,
    this.onImportComplete,
    this.showExportSection = true,
    this.embedded = false,
  });

  final VoidCallback? onImportComplete;

  /// False desde el flujo de bienvenida: en una instalación nueva todavía
  /// no hay bóveda que exportar, así que ofrecer ese botón ahí siempre fue
  /// un callejón sin salida.
  final bool showExportSection;

  /// True cuando SettingsPage la renderiza en línea en el layout ancho en
  /// vez de empujarla como su propia ruta — se salta el Scaffold/AppBar,
  /// ya que el padre ya aporta una cabecera (con flecha de volver)
  /// alrededor.
  final bool embedded;

  @override
  State<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends State<ImportExportPage> {
  final BackupService _backupService = sl<BackupService>();
  bool _isBusy = false;

  static const _typeGroup = XTypeGroup(label: 'Backup de NexusKeys', extensions: ['nexus']);

  Future<void> _export() async {
    setState(() => _isBusy = true);
    try {
      final bytes = await _backupService.buildExport();
      final fileName = 'nexuskeys_backup_${DateTime.now().millisecondsSinceEpoch}.nexus';
      final path = await _saveExport(bytes, fileName);

      if (!mounted) return;
      setState(() => _isBusy = false);
      if (path == null) return; // el usuario canceló el diálogo de guardado
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bóveda exportada'),
          content: Text('Guardada en:\n$path'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Aceptar')),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo exportar la bóveda.')),
      );
    }
  }

  /// El diálogo de guardado propio de file_selector (`getSaveLocation`)
  /// solo existe en Windows/macOS/Linux — Android no tiene equivalente
  /// ahí, así que esto usa file_picker en su lugar, que escribe [bytes] a
  /// través del Storage Access Framework en Android y un diálogo de
  /// guardado nativo en el resto, dando al usuario un "elige dónde
  /// guardar" real en todas las plataformas en las que se distribuye
  /// NexusKeys.
  Future<String?> _saveExport(Uint8List bytes, String fileName) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      dialogTitle: 'Guardar backup de NexusKeys',
      type: FileType.custom,
      allowedExtensions: const ['nexus'],
    );
    if (uri == null) return null; // el usuario canceló
    return uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
  }

  Future<void> _import() async {
    final file = await openFile(acceptedTypeGroups: const [_typeGroup]);
    if (file == null || !mounted) return;

    final password = await _promptForPassword();
    if (password == null || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final bytes = await file.readAsBytes();
      final validated = await _backupService.validateImport(bytes, password);

      if (!mounted) return;
      setState(() => _isBusy = false);

      final confirmed = await _confirmOverwrite();
      if (confirmed != true || !mounted) return;

      await _backupService.applyImport(validated);
      widget.onImportComplete?.call();
    } on BackupImportException catch (error) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo importar la bóveda.')),
      );
    }
  }

  Future<String?> _promptForPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contraseña maestra del backup'),
        content: AppPasswordField(
          controller: controller,
          hintText: 'Contraseña maestra',
          autofocus: true,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmOverwrite() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Restaurar esta bóveda?'),
        content: const Text(
          'Tu bóveda actual (si tienes una) se sustituirá por la del backup. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Restaurar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.showExportSection) ...[
          Text('EXPORTAR BÓVEDA', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Exporta tu bóveda a un archivo cifrado para guardarlo de forma segura.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isBusy ? null : _export,
              child: const Text('Exportar'),
            ),
          ),
          const SizedBox(height: 32),
        ],
        Text('IMPORTAR BÓVEDA', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Importa un archivo .nexus previamente exportado para restaurar tu bóveda.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isBusy ? null : _import,
            child: const Text('Importar'),
          ),
        ),
      ],
    );

    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Importar / Exportar')),
      body: SafeArea(child: content),
    );
  }
}
