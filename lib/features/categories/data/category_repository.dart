import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class CategoryRepository {
  final AppDatabase _db;

  CategoryRepository(this._db);

  Stream<List<Category>> watchCategories({String? type}) {
    final query = _db.select(_db.categories);
    if (type != null) {
      query.where((tbl) => tbl.type.equals(type));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]);
    return query.watch();
  }

  Future<List<Category>> getAllCategories({String? type}) {
    final query = _db.select(_db.categories);
    if (type != null) {
      query.where((tbl) => tbl.type.equals(type));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]);
    return query.get();
  }

  Future<Category?> getCategoryById(String id) {
    return (_db.select(_db.categories)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<void> createCategory(CategoriesCompanion category) {
    return _db.into(_db.categories).insert(category);
  }

  Future<bool> updateCategory(CategoriesCompanion category) {
    return _db.update(_db.categories).replace(category);
  }

  Future<int> deleteCategory(String categoryId) {
    return (_db.delete(_db.categories)..where((tbl) => tbl.id.equals(categoryId))).go();
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CategoryRepository(db);
});

final categoriesStreamProvider = StreamProvider.family<List<Category>, String?>((ref, type) {
  return ref.watch(categoryRepositoryProvider).watchCategories(type: type);
});
