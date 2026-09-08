import 'package:drift/drift.dart';
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

  /// Inspects all tables in the database to count active usages of a category
  Future<CategoryUsageInfo> getCategoryUsage(String categoryId) async {
    final txCount = await (_db.selectOnly(_db.transactions)
          ..addColumns([_db.transactions.id.count()])
          ..where(_db.transactions.categoryId.equals(categoryId)))
        .map((row) => row.read(_db.transactions.id.count()) ?? 0)
        .getSingle();

    final splitCount = await (_db.selectOnly(_db.transactionSplits)
          ..addColumns([_db.transactionSplits.id.count()])
          ..where(_db.transactionSplits.categoryId.equals(categoryId)))
        .map((row) => row.read(_db.transactionSplits.id.count()) ?? 0)
        .getSingle();

    final budgetCount = await (_db.selectOnly(_db.budgets)
          ..addColumns([_db.budgets.id.count()])
          ..where(_db.budgets.categoryId.equals(categoryId)))
        .map((row) => row.read(_db.budgets.id.count()) ?? 0)
        .getSingle();

    final recurringCount = await (_db.selectOnly(_db.recurringTransactions)
          ..addColumns([_db.recurringTransactions.id.count()])
          ..where(_db.recurringTransactions.categoryId.equals(categoryId)))
        .map((row) => row.read(_db.recurringTransactions.id.count()) ?? 0)
        .getSingle();

    return CategoryUsageInfo(
      transactionCount: txCount,
      splitCount: splitCount,
      budgetCount: budgetCount,
      recurringCount: recurringCount,
    );
  }

  /// Returns IDs of all direct transactions currently using this category
  Future<List<String>> getAssociatedTransactionIds(String categoryId) async {
    final rows = await (_db.selectOnly(_db.transactions)
          ..addColumns([_db.transactions.id])
          ..where(_db.transactions.categoryId.equals(categoryId)))
        .get();
    return rows.map((r) => r.read(_db.transactions.id)!).toList();
  }

  /// Atomically deletes a category and reassigns or uncategorizes related records
  Future<void> deleteCategoryWithReassignment({
    required String categoryId,
    String? targetCategoryId,
    bool deleteAssociatedBudget = true,
  }) async {
    await _db.transaction(() async {
      if (targetCategoryId != null && targetCategoryId.isNotEmpty) {
        // 1. Reassign direct transactions
        await (_db.update(_db.transactions)..where((t) => t.categoryId.equals(categoryId)))
            .write(TransactionsCompanion(categoryId: Value(targetCategoryId)));

        // 2. Reassign itemized split items
        await (_db.update(_db.transactionSplits)..where((s) => s.categoryId.equals(categoryId)))
            .write(TransactionSplitsCompanion(categoryId: Value(targetCategoryId)));

        // 3. Reassign recurring transactions
        await (_db.update(_db.recurringTransactions)..where((r) => r.categoryId.equals(categoryId)))
            .write(RecurringTransactionsCompanion(categoryId: Value(targetCategoryId)));
      } else {
        // 1. Mark direct transactions as Uncategorized (null categoryId)
        await (_db.update(_db.transactions)..where((t) => t.categoryId.equals(categoryId)))
            .write(const TransactionsCompanion(categoryId: Value(null)));

        // 2. For splits and recurring (schema requires non-null categoryId), fall back to general/misc
        final fallbackCat = await (_db.select(_db.categories)
              ..where((c) => c.id.equals('cat_misc_expense') | c.id.equals('cat_other_income') | c.id.equals('cat_salary')))
            .get();
        if (fallbackCat.isNotEmpty) {
          final fallbackId = fallbackCat.first.id;
          await (_db.update(_db.transactionSplits)..where((s) => s.categoryId.equals(categoryId)))
              .write(TransactionSplitsCompanion(categoryId: Value(fallbackId)));
          await (_db.update(_db.recurringTransactions)..where((r) => r.categoryId.equals(categoryId)))
              .write(RecurringTransactionsCompanion(categoryId: Value(fallbackId)));
        }
      }

      // 4. Delete associated active budgets
      if (deleteAssociatedBudget) {
        await (_db.delete(_db.budgets)..where((b) => b.categoryId.equals(categoryId))).go();
      }

      // 5. Re-parent any child subcategories to root
      await (_db.update(_db.categories)..where((c) => c.parentCategoryId.equals(categoryId)))
          .write(const CategoriesCompanion(parentCategoryId: Value(null)));

      // 6. Delete the category itself
      await (_db.delete(_db.categories)..where((c) => c.id.equals(categoryId))).go();
    });
  }

  Future<void> restoreCategory(Category category) {
    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            id: category.id,
            name: category.name,
            type: category.type,
            icon: Value(category.icon),
            color: Value(category.color),
            parentCategoryId: Value(category.parentCategoryId),
            isDefault: Value(category.isDefault),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }
}

class CategoryUsageInfo {
  final int transactionCount;
  final int splitCount;
  final int budgetCount;
  final int recurringCount;

  const CategoryUsageInfo({
    required this.transactionCount,
    required this.splitCount,
    required this.budgetCount,
    required this.recurringCount,
  });

  int get totalUsages => transactionCount + splitCount + budgetCount + recurringCount;
  bool get hasUsages => totalUsages > 0;
}


final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CategoryRepository(db);
});

final categoryOrderVersionProvider = StateProvider<int>((ref) => 0);

final categoriesStreamProvider = StreamProvider.family<List<Category>, String?>((ref, type) {
  ref.watch(categoryOrderVersionProvider);
  return ref.watch(categoryRepositoryProvider).watchCategories(type: type);
});
