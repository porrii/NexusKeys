/// The `vault_items` table shape and its migration history.
///
/// One generic table covers every item kind the spec lists (password, card,
/// note, identity, SSH, WiFi, ...): they all share the same core fields
/// (title, username, password, url, notes, category, tags, favorite,
/// color/icon, timestamps). `type` records which kind a row is, and
/// `extra_data` (JSON) carries whatever fields are specific to that kind
/// (e.g. card expiry, WiFi security type) — this avoids a rigid table per
/// item type while still supporting type-specific data. The full
/// entity/repository layer built on top of this lands in a later module;
/// this one only owns the encrypted database itself.
abstract final class VaultSchema {
  /// Bumped whenever the schema changes; [VaultDatabase] compares this
  /// against `PRAGMA user_version` to decide whether to migrate.
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

  /// Added at version 2 for img/11_categories.png's "Gestionar categorías":
  /// a managed list of category names, separate from `vault_items.category`
  /// (still a freeform string an item can carry even if it doesn't match
  /// any row here) so a category can exist — and show up with a "0" count —
  /// before any item is filed under it.
  static const String createCategoriesTable = '''
    CREATE TABLE IF NOT EXISTS categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      created_at INTEGER NOT NULL
    );
  ''';

  /// Applies every statement needed to bring a database at [currentVersion]
  /// up to [version]. Each past version's statements stay behind their own
  /// `if` so migrating from any older version replays every step in order,
  /// rather than assuming everyone upgrades from the immediately-previous
  /// version.
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
