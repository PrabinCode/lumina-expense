import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../analytics/domain/models/analytics_models.dart';



class TransactionSplitWithCategory {
  final TransactionSplit split;
  final Category category;

  TransactionSplitWithCategory({
    required this.split,
    required this.category,
  });
}

class DeletedTransactionSnapshot {
  final Transaction transaction;
  final List<TransactionSplit> splits;

  DeletedTransactionSnapshot({
    required this.transaction,
    this.splits = const [],
  });
}

class TransactionWithDetails {
  final Transaction transaction;
  final Category? category;
  final Account account;
  final Account? toAccount;
  final List<TransactionSplitWithCategory> splits;

  TransactionWithDetails({
    required this.transaction,
    this.category,
    required this.account,
    this.toAccount,
    this.splits = const [],
  });
}


class FinancialSummary {
  final double totalIncome;
  final double totalExpense;
  final double netSavings;

  FinancialSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
  });
}

class CategorySpending {
  final Category category;
  final double totalAmount;
  final double percentage;

  CategorySpending({
    required this.category,
    required this.totalAmount,
    required this.percentage,
  });
}

class TransactionRepository {
  final AppDatabase _db;

  TransactionRepository(this._db);

  /// Watch transactions joined with Account, Category, and Splits
  Stream<List<TransactionWithDetails>> watchTransactionsWithDetails({
    DateTime? startDate,
    DateTime? endDate,
    String? accountId,
    String? categoryId,
    String? type,
    String? searchQuery,
    int? limit,
  }) {
    final cat = _db.alias(_db.categories, 'c');
    final srcAcc = _db.alias(_db.accounts, 'src');
    final dstAcc = _db.alias(_db.accounts, 'dst');

    final query = _db.select(_db.transactions).join([
      leftOuterJoin(cat, cat.id.equalsExp(_db.transactions.categoryId)),
      innerJoin(srcAcc, srcAcc.id.equalsExp(_db.transactions.accountId)),
      leftOuterJoin(dstAcc, dstAcc.id.equalsExp(_db.transactions.toAccountId)),
    ]);

    if (startDate != null) {
      query.where(_db.transactions.date.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where(_db.transactions.date.isSmallerOrEqualValue(endDate));
    }
    if (accountId != null) {
      query.where(_db.transactions.accountId.equals(accountId) |
          _db.transactions.toAccountId.equals(accountId));
    }
    if (categoryId != null) {
      query.where(_db.transactions.categoryId.equals(categoryId));
    }
    if (type != null) {
      query.where(_db.transactions.type.equals(type));
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final pattern = '%${searchQuery.trim().toLowerCase()}%';
      query.where(
        _db.transactions.title.lower().like(pattern) |
            _db.transactions.note.lower().like(pattern) |
            _db.transactions.tags.lower().like(pattern),
      );
    }

    query.orderBy([
      OrderingTerm(expression: _db.transactions.date, mode: OrderingMode.desc),
      OrderingTerm(expression: _db.transactions.createdAt, mode: OrderingMode.desc),
    ]);

    if (limit != null) {
      query.limit(limit);
    }

    return query.watch().asyncMap((rows) async {
      final list = <TransactionWithDetails>[];
      for (final row in rows) {
        final tx = row.readTable(_db.transactions);
        List<TransactionSplitWithCategory> splits = [];
        if (tx.isSplit) {
          splits = await getSplitsForTransaction(tx.id);
        }

        list.add(TransactionWithDetails(
          transaction: tx,
          category: row.readTableOrNull(cat),
          account: row.readTable(srcAcc),
          toAccount: row.readTableOrNull(dstAcc),
          splits: splits,
        ));
      }
      return list;
    });
  }

  Future<void> createTransaction(TransactionsCompanion tx) {
    return _db.into(_db.transactions).insert(tx);
  }

  /// Create a transaction and its splits atomically
  Future<void> createTransactionWithSplits(
    TransactionsCompanion tx,
    List<TransactionSplitsCompanion> splits,
  ) async {
    await _db.transaction(() async {
      await _db.into(_db.transactions).insert(tx);
      for (final split in splits) {
        await _db.into(_db.transactionSplits).insert(split);
      }
    });
  }

  Future<bool> updateTransaction(TransactionsCompanion tx) {
    return _db.update(_db.transactions).replace(tx);
  }

  /// Update an existing transaction and rewrite its splits atomically
  Future<void> updateTransactionWithSplits(
    TransactionsCompanion tx,
    List<TransactionSplitsCompanion> splits,
  ) async {
    await _db.transaction(() async {
      await _db.update(_db.transactions).replace(tx);
      await (_db.delete(_db.transactionSplits)
            ..where((tbl) => tbl.transactionId.equals(tx.id.value)))
          .go();
      for (final split in splits) {
        await _db.into(_db.transactionSplits).insert(split);
      }
    });
  }

  Future<int> deleteTransaction(String id) {
    return _db.transaction(() async {
      await (_db.delete(_db.transactionSplits)..where((tbl) => tbl.transactionId.equals(id))).go();
      return (_db.delete(_db.transactions)..where((tbl) => tbl.id.equals(id))).go();
    });
  }

  Future<List<TransactionSplitWithCategory>> getSplitsForTransaction(String transactionId) async {
    final cat = _db.categories;
    final sp = _db.transactionSplits;

    final query = _db.select(sp).join([
      innerJoin(cat, cat.id.equalsExp(sp.categoryId)),
    ])..where(sp.transactionId.equals(transactionId));

    final rows = await query.get();
    return rows.map((r) {
      return TransactionSplitWithCategory(
        split: r.readTable(sp),
        category: r.readTable(cat),
      );
    }).toList();
  }

  Stream<List<TransactionSplitWithCategory>> watchSplitsForTransaction(String transactionId) {
    final cat = _db.categories;
    final sp = _db.transactionSplits;

    final query = _db.select(sp).join([
      innerJoin(cat, cat.id.equalsExp(sp.categoryId)),
    ])..where(sp.transactionId.equals(transactionId));

    return query.watch().map((rows) {
      return rows.map((r) {
        return TransactionSplitWithCategory(
          split: r.readTable(sp),
          category: r.readTable(cat),
        );
      }).toList();
    });
  }

  /// Watch financial summary for a specific date range
  Stream<FinancialSummary> watchSummary(DateTime startDate, DateTime endDate) {
    final query = _db.select(_db.transactions)
      ..where((tbl) => tbl.date.isBiggerOrEqualValue(startDate) & tbl.date.isSmallerOrEqualValue(endDate));

    return query.watch().map((txs) {
      double income = 0;
      double expense = 0;
      for (final tx in txs) {
        if (tx.type == 'income') {
          income += tx.amount;
        } else if (tx.type == 'expense') {
          expense += tx.amount;
        }
      }
      return FinancialSummary(
        totalIncome: income,
        totalExpense: expense,
        netSavings: income - expense,
      );
    });
  }

  /// Watch category spending breakdown, aggregating both direct and split transactions
  Stream<List<CategorySpending>> watchCategorySpending(DateTime startDate, DateTime endDate) {
    final cat = _db.categories;
    final tx = _db.transactions;
    final sp = _db.transactionSplits;

    // We watch transactions and splits to trigger on updates
    final txQuery = _db.select(tx)
      ..where((t) =>
          t.type.equals('expense') &
          t.date.isBiggerOrEqualValue(startDate) &
          t.date.isSmallerOrEqualValue(endDate));

    return txQuery.watch().asyncMap((expenseTxs) async {
      final allCategories = await _db.select(cat).get();
      final categoryMap = {for (var c in allCategories) c.id: c};
      final amounts = <String, double>{};
      double totalExpense = 0;

      for (final t in expenseTxs) {
        totalExpense += t.amount;
        if (t.isSplit) {
          final splits = await (_db.select(sp)..where((s) => s.transactionId.equals(t.id))).get();
          for (final s in splits) {
            amounts[s.categoryId] = (amounts[s.categoryId] ?? 0.0) + s.amount;
          }
        } else if (t.categoryId != null) {
          amounts[t.categoryId!] = (amounts[t.categoryId!] ?? 0.0) + t.amount;
        }
      }

      final results = amounts.entries.where((e) => categoryMap.containsKey(e.key)).map((e) {
        final category = categoryMap[e.key]!;
        final amount = e.value;
        final percentage = totalExpense > 0 ? (amount / totalExpense) * 100 : 0.0;
        return CategorySpending(
          category: category,
          totalAmount: amount,
          percentage: percentage,
        );
      }).toList();

      results.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
      return results;
    });
  }

  /// Bulk update category for multiple transactions
  Future<int> batchUpdateCategory(List<String> transactionIds, String categoryId) async {
    if (transactionIds.isEmpty) return 0;
    return (_db.update(_db.transactions)..where((t) => t.id.isIn(transactionIds))).write(
      TransactionsCompanion(categoryId: Value(categoryId)),
    );
  }

  /// Bulk update account for multiple transactions
  Future<int> batchUpdateAccount(List<String> transactionIds, String accountId) async {
    if (transactionIds.isEmpty) return 0;
    return (_db.update(_db.transactions)..where((t) => t.id.isIn(transactionIds))).write(
      TransactionsCompanion(accountId: Value(accountId)),
    );
  }

  /// Bulk add tag to multiple transactions
  Future<void> batchAddTag(List<String> transactionIds, String newTag) async {
    if (transactionIds.isEmpty || newTag.trim().isEmpty) return;
    final tag = newTag.trim();
    final txs = await (_db.select(_db.transactions)..where((t) => t.id.isIn(transactionIds))).get();
    for (final tx in txs) {
      final existingTags = (tx.tags ?? '').split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      if (!existingTags.contains(tag)) {
        existingTags.add(tag);
        await (_db.update(_db.transactions)..where((t) => t.id.equals(tx.id))).write(
          TransactionsCompanion(tags: Value(existingTags.join(','))),
        );
      }
    }
  }

  /// Bulk delete transactions
  Future<int> batchDeleteTransactions(List<String> transactionIds) async {
    if (transactionIds.isEmpty) return 0;
    await (_db.delete(_db.transactionSplits)..where((s) => s.transactionId.isIn(transactionIds))).go();
    return (_db.delete(_db.transactions)..where((t) => t.id.isIn(transactionIds))).go();
  }

  /// Get snapshot of transaction and its splits before deletion for Undo support
  Future<DeletedTransactionSnapshot?> getTransactionSnapshot(String id) async {
    final tx = await (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (tx == null) return null;
    final splits = await (_db.select(_db.transactionSplits)..where((s) => s.transactionId.equals(id))).get();
    return DeletedTransactionSnapshot(transaction: tx, splits: splits);
  }

  /// Get snapshots for a list of transaction IDs before batch deletion
  Future<List<DeletedTransactionSnapshot>> getBatchTransactionSnapshots(List<String> ids) async {
    final snapshots = <DeletedTransactionSnapshot>[];
    for (final id in ids) {
      final snap = await getTransactionSnapshot(id);
      if (snap != null) snapshots.add(snap);
    }
    return snapshots;
  }

  /// Restore deleted transaction and its splits atomically
  Future<void> restoreTransactionSnapshot(DeletedTransactionSnapshot snapshot) async {
    await _db.transaction(() async {
      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: snapshot.transaction.id,
              title: snapshot.transaction.title,
              amount: snapshot.transaction.amount,
              type: snapshot.transaction.type,
              categoryId: Value(snapshot.transaction.categoryId),
              accountId: snapshot.transaction.accountId,
              toAccountId: Value(snapshot.transaction.toAccountId),
              date: Value(snapshot.transaction.date),
              note: Value(snapshot.transaction.note),
              tags: Value(snapshot.transaction.tags),
              isSplit: Value(snapshot.transaction.isSplit),
              receiptPath: Value(snapshot.transaction.receiptPath),
              createdAt: Value(snapshot.transaction.createdAt),
            ),
            mode: InsertMode.insertOrReplace,
          );

      for (final split in snapshot.splits) {
        await _db.into(_db.transactionSplits).insert(
              TransactionSplitsCompanion.insert(
                id: split.id,
                transactionId: split.transactionId,
                categoryId: split.categoryId,
                amount: split.amount,
                note: Value(split.note),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }


  /// Restore a batch of deleted transactions
  Future<void> restoreBatchTransactionSnapshots(List<DeletedTransactionSnapshot> snapshots) async {
    for (final snap in snapshots) {
      await restoreTransactionSnapshot(snap);
    }
  }


  /// 1. 6-Month Comparative Cash Flow Trend
  Stream<List<CashFlowMonthlyPoint>> watchMonthlyCashFlowTrend({int months = 6}) {
    final now = DateTime.now();
    final startOfRange = DateTime(now.year, now.month - (months - 1), 1);
    final endOfRange = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final query = _db.select(_db.transactions)
      ..where((t) => t.date.isBiggerOrEqualValue(startOfRange) & t.date.isSmallerOrEqualValue(endOfRange));

    return query.watch().map((txs) {
      final points = <CashFlowMonthlyPoint>[];
      for (int i = months - 1; i >= 0; i--) {
        final monthStart = DateTime(now.year, now.month - i, 1);
        final monthEnd = DateTime(now.year, now.month - i + 1, 0, 23, 59, 59);

        double income = 0;
        double expense = 0;
        for (final tx in txs) {
          if (tx.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
              tx.date.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
            if (tx.type == 'income') {
              income += tx.amount;
            } else if (tx.type == 'expense') {
              expense += tx.amount;
            }
          }
        }
        points.add(CashFlowMonthlyPoint(
          month: monthStart,
          income: income,
          expense: expense,
          netSavings: income - expense,
        ));
      }
      return points;
    });
  }

  /// 2. Cumulative Spending Velocity Curve vs Previous Month
  Stream<SpendingVelocityData> watchSpendingVelocity(DateTime targetMonth) {
    final startOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    final endOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);
    final daysInMonth = endOfMonth.day;

    final prevMonthStart = DateTime(targetMonth.year, targetMonth.month - 1, 1);
    final prevMonthEnd = DateTime(targetMonth.year, targetMonth.month, 0, 23, 59, 59);
    final prevDaysInMonth = prevMonthEnd.day;

    final now = DateTime.now();
    final isCurrentMonth = now.year == targetMonth.year && now.month == targetMonth.month;
    final currentDay = isCurrentMonth ? now.day : daysInMonth;

    return _db.select(_db.transactions).watch().asyncMap((txs) async {
      final budgets = await _db.select(_db.budgets).get();
      final totalBudget = budgets.fold<double>(0.0, (sum, b) => sum + b.amountLimit);

      final curDailySums = List<double>.filled(daysInMonth + 1, 0.0);
      final prevDailySums = List<double>.filled(prevDaysInMonth + 1, 0.0);

      for (final tx in txs) {
        if (tx.type != 'expense') continue;
        if (tx.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
            tx.date.isBefore(endOfMonth.add(const Duration(seconds: 1)))) {
          final day = tx.date.day.clamp(1, daysInMonth);
          curDailySums[day] += tx.amount;
        } else if (tx.date.isAfter(prevMonthStart.subtract(const Duration(seconds: 1))) &&
            tx.date.isBefore(prevMonthEnd.add(const Duration(seconds: 1)))) {
          final day = tx.date.day.clamp(1, prevDaysInMonth);
          prevDailySums[day] += tx.amount;
        }
      }

      final curCumulative = <double>[];
      double curAcc = 0;
      for (int d = 1; d <= (isCurrentMonth ? currentDay : daysInMonth); d++) {
        curAcc += curDailySums[d];
        curCumulative.add(curAcc);
      }

      final prevCumulative = <double>[];
      double prevAcc = 0;
      for (int d = 1; d <= prevDaysInMonth; d++) {
        prevAcc += prevDailySums[d];
        prevCumulative.add(prevAcc);
      }

      final currentTotalSpent = curCumulative.isNotEmpty ? curCumulative.last : 0.0;
      final dailyAvg = currentDay > 0 ? (currentTotalSpent / currentDay) : 0.0;
      final projectedMonthEnd = dailyAvg * daysInMonth;

      return SpendingVelocityData(
        daysInMonth: daysInMonth,
        currentDay: currentDay,
        currentMonthCumulative: curCumulative,
        previousMonthCumulative: prevCumulative,
        totalBudgetLimit: totalBudget,
        dailyAverageSpend: dailyAvg,
        projectedMonthEndSpend: projectedMonthEnd,
      );
    });
  }

  /// 3. 50/30/20 Macro Budget Health Breakdown
  Stream<Macro503020Summary> watch50_30_20Summary(DateTime startDate, DateTime endDate) {
    return _db.select(_db.transactions).watch().map((txs) {
      double totalIncome = 0;
      double totalExpense = 0;
      double needsSpent = 0;
      double wantsSpent = 0;
      double savingsTransferred = 0;

      final rangeTxs = txs.where((t) =>
          t.date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          t.date.isBefore(endDate.add(const Duration(seconds: 1))));

      for (final tx in rangeTxs) {
        if (tx.type == 'income') {
          totalIncome += tx.amount;
          if ((tx.categoryId ?? '').contains('invest') || tx.title.toLowerCase().contains('dividend') || tx.title.toLowerCase().contains('interest')) {
            savingsTransferred += tx.amount;
          }
        } else if (tx.type == 'expense') {
          totalExpense += tx.amount;
          final catId = tx.categoryId ?? '';
          if (catId.contains('grocer') ||
              catId.contains('utilit') ||
              catId.contains('housing') ||
              catId.contains('rent') ||
              catId.contains('transport') ||
              catId.contains('health') ||
              catId.contains('educat')) {
            needsSpent += tx.amount;
          } else {
            wantsSpent += tx.amount;
          }
        }
      }

      if (totalIncome > totalExpense) {
        savingsTransferred += (totalIncome - totalExpense);
      }

      return Macro503020Summary(
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        needsSpent: needsSpent,
        wantsSpent: wantsSpent,
        savingsTransferred: savingsTransferred,
      );
    });
  }


  /// 4. Category Month-over-Month Growth Trends
  Stream<List<CategoryTrendItem>> watchCategoryMoMTrends(DateTime currentMonth) {
    final curStart = DateTime(currentMonth.year, currentMonth.month, 1);
    final curEnd = DateTime(currentMonth.year, currentMonth.month + 1, 0, 23, 59, 59);

    final prevStart = DateTime(currentMonth.year, currentMonth.month - 1, 1);
    final prevEnd = DateTime(currentMonth.year, currentMonth.month, 0, 23, 59, 59);

    final query = _db.select(_db.transactions)
      ..where((t) => t.type.equals('expense') &
          (t.date.isBiggerOrEqualValue(prevStart) & t.date.isSmallerOrEqualValue(curEnd)));

    return _db.select(_db.categories).watch().asyncMap((categories) async {
      final txs = await query.get();

      final curSums = <String, double>{};
      final prevSums = <String, double>{};

      for (final tx in txs) {
        final catId = tx.categoryId;
        if (catId == null) continue;

        if (tx.date.isAfter(curStart.subtract(const Duration(seconds: 1))) &&
            tx.date.isBefore(curEnd.add(const Duration(seconds: 1)))) {
          curSums[catId] = (curSums[catId] ?? 0) + tx.amount;
        } else if (tx.date.isAfter(prevStart.subtract(const Duration(seconds: 1))) &&
            tx.date.isBefore(prevEnd.add(const Duration(seconds: 1)))) {
          prevSums[catId] = (prevSums[catId] ?? 0) + tx.amount;
        }
      }

      final items = <CategoryTrendItem>[];
      for (final cat in categories) {
        final cur = curSums[cat.id] ?? 0.0;
        final prev = prevSums[cat.id] ?? 0.0;
        if (cur == 0 && prev == 0) continue;

        double delta = 0.0;
        if (prev > 0) {
          delta = ((cur - prev) / prev) * 100;
        } else if (cur > 0) {
          delta = 100.0;
        }

        items.add(CategoryTrendItem(
          category: cat,
          currentAmount: cur,
          previousAmount: prev,
          percentageDelta: delta,
          isIncreased: cur > prev,
        ));
      }

      items.sort((a, b) => b.currentAmount.compareTo(a.currentAmount));
      return items;
    });
  }

  /// 5. Day-of-Week Spending Heatmap
  Stream<List<DayOfWeekSpending>> watchDayOfWeekDistribution(DateTime startDate, DateTime endDate) {
    final query = _db.select(_db.transactions)
      ..where((t) => t.type.equals('expense') &
          t.date.isBiggerOrEqualValue(startDate) &
          t.date.isSmallerOrEqualValue(endDate));

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return query.watch().map((txs) {
      final dayTotals = List<double>.filled(7, 0.0);
      double total = 0.0;

      for (final tx in txs) {
        final weekday = tx.date.weekday; // 1 = Mon .. 7 = Sun
        dayTotals[weekday - 1] += tx.amount;
        total += tx.amount;
      }

      return List.generate(7, (i) {
        final amt = dayTotals[i];
        return DayOfWeekSpending(
          dayIndex: i + 1,
          dayName: dayNames[i],
          amount: amt,
          percentage: total > 0 ? (amt / total) * 100 : 0.0,
        );
      });
    });
  }

  /// 6. Tag Analytics
  Stream<List<TagSpendingItem>> watchTagAnalytics(DateTime startDate, DateTime endDate) {
    final query = _db.select(_db.transactions)
      ..where((t) => t.type.equals('expense') &
          t.date.isBiggerOrEqualValue(startDate) &
          t.date.isSmallerOrEqualValue(endDate));

    return query.watch().map((txs) {
      final tagMap = <String, (double, int)>{};

      for (final tx in txs) {
        if (tx.tags == null || tx.tags!.trim().isEmpty) continue;
        final tags = tx.tags!.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty);
        for (final tag in tags) {
          final normalized = tag.startsWith('#') ? tag : '#$tag';
          final cur = tagMap[normalized] ?? (0.0, 0);
          tagMap[normalized] = (cur.$1 + tx.amount, cur.$2 + 1);
        }
      }

      final items = tagMap.entries.map((e) {
        return TagSpendingItem(
          tag: e.key,
          amount: e.value.$1,
          count: e.value.$2,
        );
      }).toList();

      items.sort((a, b) => b.amount.compareTo(a.amount));
      return items;
    });
  }

  /// 7. Top Merchants / Payees
  Stream<List<TopMerchantItem>> watchTopMerchants(DateTime startDate, DateTime endDate, {int limit = 5}) {
    final query = _db.select(_db.transactions).join([
      leftOuterJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
    ])..where(_db.transactions.type.equals('expense') &
        _db.transactions.date.isBiggerOrEqualValue(startDate) &
        _db.transactions.date.isSmallerOrEqualValue(endDate));

    return query.watch().map((rows) {
      final map = <String, TopMerchantItem>{};

      for (final row in rows) {
        final tx = row.readTable(_db.transactions);
        final cat = row.readTableOrNull(_db.categories);
        final name = tx.title.trim();
        if (name.isEmpty) continue;

        if (map.containsKey(name)) {
          final existing = map[name]!;
          map[name] = TopMerchantItem(
            name: name,
            totalAmount: existing.totalAmount + tx.amount,
            transactionCount: existing.transactionCount + 1,
            categoryIcon: existing.categoryIcon ?? cat?.icon,
            categoryColor: existing.categoryColor ?? cat?.color,
          );
        } else {
          map[name] = TopMerchantItem(
            name: name,
            totalAmount: tx.amount,
            transactionCount: 1,
            categoryIcon: cat?.icon,
            categoryColor: cat?.color,
          );
        }
      }

      final sorted = map.values.toList()..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
      return sorted.take(limit).toList();
    });
  }
}




final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TransactionRepository(db);
});

final recentTransactionsStreamProvider = StreamProvider<List<TransactionWithDetails>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchTransactionsWithDetails(limit: 15);
});

final currentMonthSummaryStreamProvider = StreamProvider<FinancialSummary>((ref) {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  return ref.watch(transactionRepositoryProvider).watchSummary(startOfMonth, endOfMonth);
});
