import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/widgets/app_password_field.dart';
import '../../domain/services/backup_service.dart';

/// Reproduces img/09_import_export.png. Reused both from Ajustes (export a
/// backup, or restore one over the current vault) and from
/// img/02_welcome.png's "Abrir bóveda existente" (import to bootstrap a
/// vault on a fresh install) — [onImportComplete] lets each caller decide
/// what happens after a successful restore, since that differs: Ajustes
/// needs to drop back to the lock screen (the auth header was just
/// replaced), the welcome flow needs to unlock straight in.
class ImportExportPage extends StatefulWidget {
  const ImportExportPage({
    super.key,
    this.onImportComplete,
    this.showExportSection = true,
    this.embedded = false,
  });

  final VoidCallback? onImportComplete;

  /// False from the welcome flow: there's no vault to export yet on a
  /// fresh install, so offering that button there was always a dead end.
  final bool showExportSection;

  /// True when SettingsPage renders this inline in the wide layout instead
  /// of pushing it as its own route — skips the Scaffold/AppBar, since the
  /// parent already supplies a header (with a back arrow) around it.
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
      if (path == null) return; // user cancelled the save dialog
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

  /// file_selector's own save dialog (`getSaveLocation`) only exists on
  /// Windows/macOS/Linux — Android has no equivalent there, so this uses
  /// file_picker instead, which writes [bytes] through Android's Storage
  /// Access Framework on Android and a native save dialog everywhere else,
  /// giving the user a real "choose where to save" prompt on every
  /// platform NexusKeys ships on.
  Future<String?> _saveExport(Uint8List bytes, String fileName) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      dialogTitle: 'Guardar backup de NexusKeys',
      type: FileType.custom,
      allowedExtensions: const ['nexus'],
    );
    if (uri == null) return null; // user cancelled
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
