import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'vault_database.dart';

/// Es dueña del ciclo de vida de la [VaultDatabase] abierta en cada
/// momento, si la hay.
///
/// Se registra como una única instancia de larga vida en el service
/// locator para que todas las capas coincidan en si la bóveda está
/// desbloqueada ahora mismo: el flujo de autenticación llama a
/// [unlock]/[lock], y una vez existe la feature de CRUD de la bóveda esta
/// lee [database] para ejecutar consultas — nadie reabre el archivo por su
/// cuenta ni guarda su propia copia de la clave.
class VaultSession {
  VaultSession({this.overrideDirectory});

  static const _fileName = 'vault.db';

  /// Solo lo fijan los tests, para redirigir la base de datos de la bóveda
  /// a un directorio temporal en vez del directorio real de soporte de la
  /// app.
  final Directory? overrideDirectory;

  VaultDatabase? _database;

  bool get isUnlocked => _database != null;

  /// La conexión activa. Lanza [StateError] si la bóveda está bloqueada —
  /// quien llama aquí solo llega tras un [unlock] correcto, así que una
  /// comprobación de null aquí solo taparía un bug real en quien llama.
  VaultDatabase get database {
    final db = _database;
    if (db == null) throw StateError('VaultSession.database read while the vault is locked');
    return db;
  }

  Future<void> unlock(Uint8List key) async {
    _database?.close();
    _database = VaultDatabase.open(await _resolvePath(), key);
  }

  /// La ubicación de la base de datos de la bóveda en disco — para la
  /// feature de copias de seguridad, que necesita leer/reemplazar el
  /// archivo en crudo (ya cifrado) directamente y no a través de una
  /// conexión viva.
  Future<File> resolveDatabaseFile() async => File(await _resolvePath());

  Future<String> _resolvePath() async {
    final dir = overrideDirectory ?? await getApplicationSupportDirectory();
    return '${dir.path}${Platform.pathSeparator}$_fileName';
  }

  /// Vuelve a cifrar la base de datos abierta bajo [newKey] — llámalo
  /// siempre que cambie la contraseña maestra, justo después de derivar la
  /// nueva clave, para que la bóveda siga siendo descifrable con ella.
  /// Lanza [StateError] si está bloqueada.
  void rekey(Uint8List newKey) => database.rekey(newKey);

  void lock() {
    _database?.close();
    _database = null;
  }
}
