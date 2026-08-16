import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class CategoryRepository {
  final AppDatabase _db;
  static const _keyOrderPrefix = 'category_order_';

  CategoryRepository(this._db);

  Stream<List<Category>> watchCategories({String? type}) {
    final query = _db.select(_db.categories);
    if (type != null) {
      query.where((tbl) => tbl.type.equals(type));
    }
    return query.watch().asyncMap((categories) async {
      return _applyCustomOrder(categories, type);
    });
  }

  Future<List<Category>> getAllCategories({String? type}) async {
    final query = _db.select(_db.categories);
    if (type != null) {
      query.where((tbl) => tbl.type.equals(type));
    }
    final list = await query.get();
    return _applyCustomOrder(list, type);
  }

  Future<List<Category>> _applyCustomOrder(List<Category> categories, String? type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyOrderPrefix${type ?? 'all'}';
      final orderList = prefs.getStringList(key);
      if (orderList == null || orderList.isEmpty) {
        return categories;
      }

      final orderMap = {for (int i = 0; i < orderList.length; i++) orderList[i]: i};
      final sorted = List<Category>.from(categories);
      sorted.sort((a, b) {
        final posA = orderMap[a.id] ?? 9999;
        final posB = orderMap[b.id] ?? 9999;
        if (posA != posB) return posA.compareTo(posB);
        return a.name.compareTo(b.name);
      });
      return sorted;
    } catch (_) {
      return categories;
    }
  }

  Future<void> saveCategoryOrder(List<String> categoryIds, String? type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyOrderPrefix${type ?? 'all'}';
      await prefs.setStringList(key, categoryIds);
    } catch (_) {}
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
