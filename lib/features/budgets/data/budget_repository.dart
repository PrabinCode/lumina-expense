import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class BudgetWithProgress {
  final Budget budget;
  final Category category;
  final double currentSpent;
  final double percentage;
  final int transactionCount;

  BudgetWithProgress({
    required this.budget,
    required this.category,
    required this.currentSpent,
    required this.percentage,
    this.transactionCount = 0,
  });

  bool get isOverBudget => currentSpent > budget.amountLimit;
  bool get isNearLimit => percentage >= 80.0 && !isOverBudget;
  double get remaining => budget.amountLimit - currentSpent;
}

class BudgetRepository {
  final AppDatabase _db;

  BudgetRepository(this._db);

  Future<List<BudgetWithProgress>> getBudgetsWithProgress(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final cat = _db.categories;
    final b = _db.budgets;

    final query = _db.select(b).join([
      innerJoin(cat, cat.id.equalsExp(b.categoryId)),
    ]);

    final rows = await query.get();
    if (rows.isEmpty) return [];

    // Pre-fetch all direct expenses for the month in a single query
    final directTxs = await (_db.select(_db.transactions)
          ..where((t) =>
              t.type.equals('expense') &
              t.isSplit.equals(false) &
              t.date.isBiggerOrEqualValue(startOfMonth) &
              t.date.isSmallerOrEqualValue(endOfMonth)))
        .get();

    // Pre-fetch all split expenses for the month in a single query
    final splitRows = await (_db.select(_db.transactionSplits).join([
      innerJoin(_db.transactions, _db.transactions.id.equalsExp(_db.transactionSplits.transactionId)),
    ])
          ..where(_db.transactions.type.equals('expense') &
              _db.transactions.date.isBiggerOrEqualValue(startOfMonth) &
              _db.transactions.date.isSmallerOrEqualValue(endOfMonth)))
        .get();

    // Map spending and counts by category ID
    final categorySpent = <String, double>{};
    final categoryTxCount = <String, int>{};

    for (final tx in directTxs) {
      if (tx.categoryId != null) {
        categorySpent[tx.categoryId!] = (categorySpent[tx.categoryId!] ?? 0.0) + tx.amount;
        categoryTxCount[tx.categoryId!] = (categoryTxCount[tx.categoryId!] ?? 0) + 1;
      }
    }

    for (final r in splitRows) {
      final s = r.readTable(_db.transactionSplits);
      categorySpent[s.categoryId] = (categorySpent[s.categoryId] ?? 0.0) + s.amount;
      categoryTxCount[s.categoryId] = (categoryTxCount[s.categoryId] ?? 0) + 1;
    }

    final results = <BudgetWithProgress>[];

    for (final row in rows) {
      final budget = row.readTable(b);
      final category = row.readTable(cat);
      final spent = categorySpent[category.id] ?? 0.0;
      final txCount = categoryTxCount[category.id] ?? 0;
      final percentage = budget.amountLimit > 0 ? (spent / budget.amountLimit) * 100 : 0.0;

      results.add(BudgetWithProgress(
        budget: budget,
        category: category,
        currentSpent: spent,
        percentage: percentage,
        transactionCount: txCount,
      ));
    }

    results.sort((a, b) => b.percentage.compareTo(a.percentage));
    return results;
  }

  Stream<List<BudgetWithProgress>> watchBudgetsWithProgress(DateTime month) {
    late StreamController<List<BudgetWithProgress>> controller;
    StreamSubscription? sub1;
    StreamSubscription? sub2;
    StreamSubscription? sub3;

    Future<void> emitBudgets() async {
      if (controller.isClosed) return;
      try {
        final results = await getBudgetsWithProgress(month);
        if (!controller.isClosed) {
          controller.add(results);
        }
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
        }
      }
    }

    controller = StreamController<List<BudgetWithProgress>>(
      onListen: () {
        emitBudgets();
        final cat = _db.categories;
        final b = _db.budgets;
        final query = _db.select(b).join([
          innerJoin(cat, cat.id.equalsExp(b.categoryId)),
        ]);
        sub1 = query.watch().listen((_) => emitBudgets());
        sub2 = _db.select(_db.transactions).watch().listen((_) => emitBudgets());
        sub3 = _db.select(_db.transactionSplits).watch().listen((_) => emitBudgets());
      },
      onCancel: () async {
        await sub1?.cancel();
        await sub2?.cancel();
        await sub3?.cancel();
      },
    );

    return controller.stream;
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

  Future<void> restoreBudget(Budget budget) {
    return _db.into(_db.budgets).insert(
          BudgetsCompanion.insert(
            id: budget.id,
            categoryId: budget.categoryId,
            amountLimit: budget.amountLimit,
            period: Value(budget.period),
            startDate: Value(budget.startDate),
          ),
          mode: InsertMode.insertOrReplace,
        );
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

final monthBudgetsProvider = StreamProvider.family<List<BudgetWithProgress>, DateTime>((ref, month) {
  return ref.watch(budgetRepositoryProvider).watchBudgetsWithProgress(month);
});
