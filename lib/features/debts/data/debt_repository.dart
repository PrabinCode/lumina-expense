import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class DebtSummary {
  final double totalLent; // Money people owe me
  final double totalBorrowed; // Money I owe others
  final double netReceivable;

  DebtSummary({
    required this.totalLent,
    required this.totalBorrowed,
    required this.netReceivable,
  });
}

class DebtRepository {
  final AppDatabase _db;

  DebtRepository(this._db);

  Stream<List<Debt>> watchDebts({bool? isSettled, String? type}) {
    final query = _db.select(_db.debts);
    if (isSettled != null) {
      query.where((tbl) => tbl.isSettled.equals(isSettled));
    }
    if (type != null) {
      query.where((tbl) => tbl.type.equals(type));
    }
    query.orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]);
    return query.watch();
  }

  Future<void> createDebt(DebtsCompanion debt) {
    return _db.into(_db.debts).insert(debt);
  }

  Future<bool> updateDebt(DebtsCompanion debt) {
    return _db.update(_db.debts).replace(debt);
  }

  Future<int> deleteDebt(String id) {
    return (_db.delete(_db.debts)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<void> recordSettlement(String id, double additionalSettledAmount) async {
    final existing = await (_db.select(_db.debts)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (existing == null) return;

    final newSettled = existing.settledAmount + additionalSettledAmount;
    final isFullySettled = newSettled >= existing.amount;

    await (_db.update(_db.debts)..where((tbl) => tbl.id.equals(id))).write(
      DebtsCompanion(
        settledAmount: Value(newSettled),
        isSettled: Value(isFullySettled),
      ),
    );
  }

  Stream<DebtSummary> watchDebtSummary() {
    return _db.select(_db.debts).watch().map((debts) {
      double lent = 0;
      double borrowed = 0;

      for (final d in debts) {
        final remaining = d.amount - d.settledAmount;
        if (remaining > 0) {
          if (d.type == 'lent') {
            lent += remaining;
          } else if (d.type == 'borrowed') {
            borrowed += remaining;
          }
        }
      }

      return DebtSummary(
        totalLent: lent,
        totalBorrowed: borrowed,
        netReceivable: lent - borrowed,
      );
    });
  }
}

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DebtRepository(db);
});

final debtsStreamProvider = StreamProvider.family<List<Debt>, bool?>((ref, isSettled) {
  return ref.watch(debtRepositoryProvider).watchDebts(isSettled: isSettled);
});

final debtSummaryStreamProvider = StreamProvider<DebtSummary>((ref) {
  return ref.watch(debtRepositoryProvider).watchDebtSummary();
});
