import '../entities/category.dart';

/// See [VaultRepository]'s doc comment for why this exposes a synchronous
/// [currentCategories] getter alongside a plain (non-replaying)
/// [categoriesStream] rather than one stream that replays its latest value.
abstract interface class CategoryRepository {
  /// Every managed category, oldest first — as of the last mutation or
  /// [reload].
  List<Category> get currentCategories;

  Stream<List<Category>> get categoriesStream;

  /// Creates a category named [name]. Throws [ArgumentError] if a category
  /// with that name already exists — names are unique, matching how the
  /// list can only show one row per name.
  Future<Category> create(String name);

  Future<void> delete(int id);

  /// Re-queries [currentCategories] against whatever database connection
  /// [VaultSession] currently holds. Must be called after every unlock.
  Future<void> reload();

  void dispose();
}
