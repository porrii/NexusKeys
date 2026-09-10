import 'package:sqlite3/sqlite3.dart';

import '../../../../core/database/vault_session.dart';

/// SQL en crudo contra la base de datos cifrada abierta en ese momento.
///
/// Lee [VaultSession.database] fresco en cada llamada en vez de cachear
/// una referencia a [Database] — la sesión abre una conexión totalmente
/// nueva en cada desbloqueo, así que aferrarse a una antigua significaría
/// consultar en silencio una conexión cerrada y desechada tras un ciclo de
/// bloqueo/desbloqueo.
class VaultLocalDataSource {
  VaultLocalDataSource({required VaultSession vaultSession}) : _session = vaultSession;

  static const _columns = [
    'id',
    'type',
    'title',
    'username',
    'password',
    'url',
    'notes',
    'category',
    'tags',
    'color',
    'icon',
    'extra_data',
    'is_favorite',
    'is_deleted',
    'created_at',
    'updated_at',
    'deleted_at',
  ];

  final VaultSession _session;

  Database get _db => _session.database.raw;

  List<Map<String, Object?>> selectAll({required bool deleted}) {
    final result = _db.select(
      'SELECT * FROM vault_items WHERE is_deleted = ? ORDER BY updated_at DESC;',
      [deleted ? 1 : 0],
    );
    return result.map(_rowToMap).toList();
  }

  Map<String, Object?> _rowToMap(Row row) => {for (final c in _columns) c: row[c]};

  int insert(Map<String, Object?> values) {
    _db.execute(
      'INSERT INTO vault_items '
      '(type, title, username, password, url, notes, category, tags, color, icon, extra_data, '
      'is_favorite, is_deleted, created_at, updated_at, deleted_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
      [
        values['type'],
        values['title'],
        values['username'],
        values['password'],
        values['url'],
        values['notes'],
        values['category'],
        values['tags'],
        values['color'],
        values['icon'],
        values['extra_data'],
        values['is_favorite'],
        values['is_deleted'],
        values['created_at'],
        values['updated_at'],
        values['deleted_at'],
      ],
    );
    return _db.lastInsertRowId;
  }

  void update(int id, Map<String, Object?> values) {
    _db.execute(
      'UPDATE vault_items SET type=?, title=?, username=?, password=?, url=?, notes=?, '
      'category=?, tags=?, color=?, icon=?, extra_data=?, updated_at=? WHERE id=?;',
      [
        values['type'],
        values['title'],
        values['username'],
        values['password'],
        values['url'],
        values['notes'],
        values['category'],
        values['tags'],
        values['color'],
        values['icon'],
        values['extra_data'],
        values['updated_at'],
        id,
      ],
    );
  }

  void setFavorite(int id, bool isFavorite) {
    _db.execute('UPDATE vault_items SET is_favorite = ? WHERE id = ?;', [isFavorite ? 1 : 0, id]);
  }

  void softDelete(int id, int deletedAtMillis) {
    _db.execute(
      'UPDATE vault_items SET is_deleted = 1, deleted_at = ? WHERE id = ?;',
      [deletedAtMillis, id],
    );
  }

  void restore(int id) {
    _db.execute('UPDATE vault_items SET is_deleted = 0, deleted_at = NULL WHERE id = ?;', [id]);
  }

  void hardDelete(int id) {
    _db.execute('DELETE FROM vault_items WHERE id = ?;', [id]);
  }
}
