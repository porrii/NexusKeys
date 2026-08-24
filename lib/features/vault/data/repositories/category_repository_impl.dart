import 'dart:async';

import 'package:sqlite3/sqlite3.dart';

import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/category_local_data_source.dart';

/// See [CategoryRepository]'s doc comment for why [currentCategories]/
/// [categoriesStream] are split instead of one replaying Stream.
class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl({required CategoryLocalDataSource dataSource}) : _local = dataSource {
    _refresh();
  }

  final CategoryLocalDataSource _local;
  final _controller = StreamController<List<Category>>.broadcast();

  @override
  List<Category> currentCategories = const [];

  @override
  Stream<List<Category>> get categoriesStream => _controller.stream;

  void _refresh() {
    currentCategories = _local.selectAll().map(Category.fromMap).toList();
    _controller.add(currentCategories);
  }

  @override
  Future<Category> create(String name) async {
    final int id;
    try {
      id = _local.insert({'name': name, 'created_at': DateTime.now().toUtc().millisecondsSinceEpoch});
    } on SqliteException catch (error) {
      if (error.message.contains('UNIQUE constraint failed')) {
        throw ArgumentError('A category named "$name" already exists');
      }
      rethrow;
    }
    _refresh();
    return currentCategories.firstWhere((c) => c.id == id);
  }

  @override
  Future<void> delete(int id) async {
    _local.delete(id);
    _refresh();
  }

  @override
  Future<void> reload() async => _refresh();

  @override
  void dispose() {
    _controller.close();
  }
}
