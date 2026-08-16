import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class TransactionSplitWithCategory {
  final TransactionSplit split;
  final Category category;

  TransactionSplitWithCategory({
    required this.split,
    required this.category,
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
