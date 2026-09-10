/// La forma de la tabla `vault_items` y su historial de migraciones.
///
/// Una única tabla genérica cubre todos los tipos de elemento que lista la
/// especificación (contraseña, tarjeta, nota, identidad, SSH, WiFi, ...):
/// todos comparten los mismos campos base (título, usuario, contraseña,
/// url, notas, categoría, etiquetas, favorito, color/icono, marcas de
/// tiempo). `type` registra de qué tipo es una fila, y `extra_data` (JSON)
/// lleva los campos específicos de ese tipo (p. ej. la caducidad de una
/// tarjeta o el tipo de seguridad de una WiFi) — así se evita una tabla
/// rígida por tipo de elemento sin dejar de admitir datos específicos de
/// cada tipo. La capa completa de entidades/repositorios que se monta
/// encima llega en un módulo posterior; esta solo es dueña de la base de
/// datos cifrada en sí.
abstract final class VaultSchema {
  /// Se sube cada vez que cambia el esquema; [VaultDatabase] lo compara con
  /// `PRAGMA user_version` para decidir si migrar.
  static const int version = 2;

  static const String createVaultItemsTable = '''
    CREATE TABLE IF NOT EXISTS vault_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      title TEXT NOT NULL,
      username TEXT,
      password TEXT,
      url TEXT,
      notes TEXT,
      category TEXT,
      tags TEXT,
      color TEXT,
      icon TEXT,
      extra_data TEXT,
      is_favorite INTEGER NOT NULL DEFAULT 0,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER
    );
  ''';

  static const List<String> createIndices = [
    'CREATE INDEX IF NOT EXISTS idx_vault_items_category ON vault_items(category);',
    'CREATE INDEX IF NOT EXISTS idx_vault_items_favorite ON vault_items(is_favorite);',
    'CREATE INDEX IF NOT EXISTS idx_vault_items_deleted ON vault_items(is_deleted);',
    'CREATE INDEX IF NOT EXISTS idx_vault_items_updated_at ON vault_items(updated_at);',
  ];

  /// Añadida en la versión 2 para el "Gestionar categorías" de
  /// img/11_categories.png: una lista gestionada de nombres de categoría,
  /// separada de `vault_items.category` (que sigue siendo una cadena libre
  /// que un elemento puede llevar aunque no coincida con ninguna fila de
  /// aquí) para que una categoría pueda existir — y aparecer con un "0" —
  /// antes de que haya ningún elemento archivado en ella.
  static const String createCategoriesTable = '''
    CREATE TABLE IF NOT EXISTS categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      created_at INTEGER NOT NULL
    );
  ''';

  /// Aplica todas las sentencias necesarias para llevar una base de datos
  /// en [currentVersion] hasta [version]. Las sentencias de cada versión
  /// pasada se quedan tras su propio `if`, así que migrar desde cualquier
  /// versión más antigua reproduce cada paso en orden, en vez de asumir
  /// que todo el mundo actualiza desde la versión inmediatamente anterior.
  static List<String> migrationFrom(int currentVersion) {
    final statements = <String>[];
    if (currentVersion < 1) {
      statements.addAll([createVaultItemsTable, ...createIndices]);
    }
    if (currentVersion < 2) {
      statements.add(createCategoriesTable);
    }
    return statements;
  }

  const VaultSchema._();
}
