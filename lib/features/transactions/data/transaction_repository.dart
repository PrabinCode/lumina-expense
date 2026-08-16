import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class TransactionWithDetails {
  final Transaction transaction;
  final Category? category;
  final Account account;
  final Account? toAccount;

  TransactionWithDetails({
    required this.transaction,
    this.category,
    required this.account,
    this.toAccount,
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

  /// Watch transactions joined with Account and Category
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

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithDetails(
          transaction: row.readTable(_db.transactions),
          category: row.readTableOrNull(cat),
          account: row.readTable(srcAcc),
          toAccount: row.readTableOrNull(dstAcc),
        );
      }).toList();
    });
  }

  Future<void> createTransaction(TransactionsCompanion tx) {
    return _db.into(_db.transactions).insert(tx);
  }

  Future<bool> updateTransaction(TransactionsCompanion tx) {
    return _db.update(_db.transactions).replace(tx);
  }

  Future<int> deleteTransaction(String id) {
    return (_db.delete(_db.transactions)..where((tbl) => tbl.id.equals(id))).go();
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

  /// Watch category spending breakdown
  Stream<List<CategorySpending>> watchCategorySpending(DateTime startDate, DateTime endDate) {
    final cat = _db.categories;
    final tx = _db.transactions;

    final query = _db.select(tx).join([
      innerJoin(cat, cat.id.equalsExp(tx.categoryId)),
    ])
      ..where(tx.type.equals('expense') &
          tx.date.isBiggerOrEqualValue(startDate) &
          tx.date.isSmallerOrEqualValue(endDate));

    return query.watch().map((rows) {
      final categoryMap = <String, Category>{};
      final amounts = <String, double>{};
      double totalExpense = 0;

      for (final row in rows) {
        final c = row.readTable(cat);
        final t = row.readTable(tx);
        categoryMap[c.id] = c;
        amounts[c.id] = (amounts[c.id] ?? 0.0) + t.amount;
        totalExpense += t.amount;
      }

      final results = amounts.entries.map((e) {
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
