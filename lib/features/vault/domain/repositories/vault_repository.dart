import '../entities/vault_item.dart';

/// CRUD access to the encrypted vault. Every stream re-emits the full,
/// current list after any mutating call below — there's a single writer
/// (this app, one process), so re-querying on write is simpler than real
/// change-data-capture and is not a meaningful performance concern at
/// vault-sized row counts.
///
/// [currentItems]/[currentTrash] and [itemsStream]/[trashStream] are
/// deliberately separate rather than one Stream that replays its latest
/// value to new subscribers: hand-rolling that replay with an `async*`
/// generator racing a broadcast controller is a real footgun (a mutation
/// that runs synchronously — as every one here does, `package:sqlite3` has
/// no async I/O — can beat the generator's own first `yield` to the punch
/// and silently drop events). A plain getter for "right now" plus a plain
/// change-notification stream sidesteps that entirely, and is exactly what
/// `StreamBuilder(initialData: ..., stream: ...)` wants anyway.
abstract interface class VaultRepository {
  /// Non-deleted items, most recently updated first, as of the last
  /// mutation or [reload].
  List<VaultItem> get currentItems;

  /// Items currently in the trash (Papelera), most recently deleted first.
  List<VaultItem> get currentTrash;

  /// Emits the full active list after every mutation and [reload].
  Stream<List<VaultItem>> get itemsStream;

  /// Emits the full trash list after every mutation and [reload].
  Stream<List<VaultItem>> get trashStream;

  /// Inserts [draft] (its `id` is ignored) and returns it as actually
  /// persisted — re-read from storage rather than [draft] itself, since
  /// timestamps are millisecond-truncated on the way into SQLite and
  /// [draft] may carry sub-millisecond precision that was never stored.
  Future<VaultItem> create(VaultItem draft);

  /// Persists every field of [item] except `id`/`createdAt`; `updatedAt` is
  /// refreshed to now regardless of what [item] carries.
  Future<void> update(VaultItem item);

  Future<void> setFavorite(int id, bool isFavorite);

  /// Soft-delete: moves the item to the trash without erasing it.
  Future<void> moveToTrash(int id);

  Future<void> restoreFromTrash(int id);

  /// Erases the row. Only valid for items already in the trash.
  Future<void> deletePermanently(int id);

  /// Re-queries [currentItems]/[currentTrash] and re-broadcasts both
  /// streams against whatever database connection [VaultSession] currently
  /// holds. Must be called after every unlock — not just the first one in
  /// the app's lifetime — or a re-unlock following a lock would keep
  /// serving stale data from the previous session.
  Future<void> reload();

  /// Releases the stream controllers. Call when the vault locks.
  void dispose();
}
