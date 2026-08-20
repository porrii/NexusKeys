import 'dart:async';

import '../../domain/entities/vault_item.dart';
import '../../domain/repositories/vault_repository.dart';
import '../datasources/vault_local_data_source.dart';

/// See [VaultRepository]'s doc comment for why [currentItems]/[itemsStream]
/// are split instead of one replaying Stream.
class VaultRepositoryImpl implements VaultRepository {
  VaultRepositoryImpl({required VaultLocalDataSource dataSource}) : _local = dataSource {
    _refresh();
  }

  final VaultLocalDataSource _local;
  final _itemsController = StreamController<List<VaultItem>>.broadcast();
  final _trashController = StreamController<List<VaultItem>>.broadcast();

  @override
  List<VaultItem> currentItems = const [];

  @override
  List<VaultItem> currentTrash = const [];

  @override
  Stream<List<VaultItem>> get itemsStream => _itemsController.stream;

  @override
  Stream<List<VaultItem>> get trashStream => _trashController.stream;

  void _refresh() {
    currentItems = _local.selectAll(deleted: false).map(VaultItem.fromMap).toList();
    currentTrash = _local.selectAll(deleted: true).map(VaultItem.fromMap).toList();
    _itemsController.add(currentItems);
    _trashController.add(currentTrash);
  }

  @override
  Future<VaultItem> create(VaultItem draft) async {
    final id = _local.insert(draft.toMap());
    _refresh();
    return currentItems.firstWhere((i) => i.id == id);
  }

  @override
  Future<void> update(VaultItem item) async {
    final id = item.id;
    if (id == null) {
      throw ArgumentError('Cannot update a VaultItem that was never created (id is null)');
    }
    final refreshed = item.copyWith(updatedAt: DateTime.now());
    _local.update(id, refreshed.toMap());
    _refresh();
  }

  @override
  Future<void> setFavorite(int id, bool isFavorite) async {
    _local.setFavorite(id, isFavorite);
    _refresh();
  }

  @override
  Future<void> moveToTrash(int id) async {
    _local.softDelete(id, DateTime.now().millisecondsSinceEpoch);
    _refresh();
  }

  @override
  Future<void> restoreFromTrash(int id) async {
    _local.restore(id);
    _refresh();
  }

  @override
  Future<void> deletePermanently(int id) async {
    _local.hardDelete(id);
    _refresh();
  }

  @override
  Future<void> reload() async => _refresh();

  @override
  void dispose() {
    _itemsController.close();
    _trashController.close();
  }
}
