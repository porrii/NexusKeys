import 'package:sqlite3/sqlite3.dart';

import '../../../../core/database/vault_session.dart';

/// Raw SQL against the currently-open encrypted database. See
/// [VaultLocalDataSource]'s doc comment for why this reads
/// [VaultSession.database] fresh on every call.
class CategoryLocalDataSource {
  CategoryLocalDataSource({required VaultSession vaultSession}) : _session = vaultSession;

  final VaultSession _session;

  Database get _db => _session.database.raw;

  List<Map<String, Object?>> selectAll() {
    final result = _db.select('SELECT * FROM categories ORDER BY created_at ASC;');
    return result.map((row) => {'id': row['id'], 'name': row['name'], 'created_at': row['created_at']}).toList();
  }

  int insert(Map<String, Object?> values) {
    _db.execute(
      'INSERT INTO categories (name, created_at) VALUES (?, ?);',
      [values['name'], values['created_at']],
    );
    return _db.lastInsertRowId;
  }

  void delete(int id) {
    _db.execute('DELETE FROM categories WHERE id = ?;', [id]);
  }
}
