import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class BudgetWithProgress {
  final Budget budget;
  final Category category;
  final double currentSpent;
  final double percentage;

  BudgetWithProgress({
    required this.budget,
    required this.category,
    required this.currentSpent,
    required this.percentage,
  });

  bool get isOverBudget => currentSpent > budget.amountLimit;
  bool get isNearLimit => percentage >= 80.0 && !isOverBudget;
  double get remaining => budget.amountLimit - currentSpent;
}

class BudgetRepository {
  final AppDatabase _db;

  BudgetRepository(this._db);

  Stream<List<BudgetWithProgress>> watchBudgetsWithProgress(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final cat = _db.categories;
    final b = _db.budgets;

    final query = _db.select(b).join([
      innerJoin(cat, cat.id.equalsExp(b.categoryId)),
    ]);

    return query.watch().asyncMap((rows) async {
      final results = <BudgetWithProgress>[];

      for (final row in rows) {
        final budget = row.readTable(b);
        final category = row.readTable(cat);

        // Compute spent in this month for this category
        final transactions = await (_db.select(_db.transactions)
              ..where((t) =>
                  t.categoryId.equals(category.id) &
                  t.type.equals('expense') &
                  t.date.isBiggerOrEqualValue(startOfMonth) &
                  t.date.isSmallerOrEqualValue(endOfMonth)))
            .get();

        final spent = transactions.fold<double>(0.0, (sum, t) => sum + t.amount);
        final percentage = budget.amountLimit > 0 ? (spent / budget.amountLimit) * 100 : 0.0;

        results.add(BudgetWithProgress(
          budget: budget,
          category: category,
          currentSpent: spent,
          percentage: percentage,
        ));
      }

      results.sort((a, b) => b.percentage.compareTo(a.percentage));
      return results;
    });
  }

  Future<void> createBudget(BudgetsCompanion budget) {
    return _db.into(_db.budgets).insert(budget);
  }

  Future<bool> updateBudget(BudgetsCompanion budget) {
    return _db.update(_db.budgets).replace(budget);
  }

  Future<int> deleteBudget(String id) {
    return (_db.delete(_db.budgets)..where((tbl) => tbl.id.equals(id))).go();
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BudgetRepository(db);
});

final currentMonthBudgetsProvider = StreamProvider<List<BudgetWithProgress>>((ref) {
  final now = DateTime.now();
  return ref.watch(budgetRepositoryProvider).watchBudgetsWithProgress(now);
});
