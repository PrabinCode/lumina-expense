import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class AccountWithBalance {
  final Account account;
  final double currentBalance;

  AccountWithBalance({
    required this.account,
    required this.currentBalance,
  });
}

class AccountRepository {
  final AppDatabase _db;

  AccountRepository(this._db);

  Stream<List<Account>> watchAllAccounts({bool includeArchived = false}) {
    final query = _db.select(_db.accounts);
    if (!includeArchived) {
      query.where((tbl) => tbl.isArchived.equals(false));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]);
    return query.watch();
  }

  Future<List<Account>> getAllAccounts({bool includeArchived = false}) {
    final query = _db.select(_db.accounts);
    if (!includeArchived) {
      query.where((tbl) => tbl.isArchived.equals(false));
    }
    return query.get();
  }

  Future<Account?> getAccountById(String id) {
    return (_db.select(_db.accounts)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<void> createAccount(AccountsCompanion account) {
    return _db.into(_db.accounts).insert(account);
  }

  Future<bool> updateAccount(AccountsCompanion account) {
    return _db.update(_db.accounts).replace(account);
  }

  Future<int> setArchived(String accountId, bool isArchived) {
    return (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(accountId))).write(
      AccountsCompanion(isArchived: Value(isArchived)),
    );
  }

  Future<int> deleteAccount(String accountId) {
    return (_db.delete(_db.accounts)..where((tbl) => tbl.id.equals(accountId))).go();
  }

  /// Watch accounts with real-time computed balances
  Stream<List<AccountWithBalance>> watchAccountsWithBalances() {
    return watchAllAccounts().asyncMap((accountsList) async {
      final results = <AccountWithBalance>[];

      for (final acc in accountsList) {
        final balance = await computeAccountBalance(acc.id, acc.initialBalance);
        results.add(AccountWithBalance(account: acc, currentBalance: balance));
      }

      return results;
    });
  }

  /// Compute current balance = initialBalance + Income - Expense - OutgoingTransfers + IncomingTransfers
  Future<double> computeAccountBalance(String accountId, double initialBalance) async {
    final transactions = await (_db.select(_db.transactions)
          ..where((tbl) => tbl.accountId.equals(accountId) | tbl.toAccountId.equals(accountId)))
        .get();

    double balance = initialBalance;
    for (final tx in transactions) {
      if (tx.type == 'income' && tx.accountId == accountId) {
        balance += tx.amount;
      } else if (tx.type == 'expense' && tx.accountId == accountId) {
        balance -= tx.amount;
      } else if (tx.type == 'transfer') {
        if (tx.accountId == accountId) {
          balance -= tx.amount; // Outgoing transfer
        }
        if (tx.toAccountId == accountId) {
          balance += tx.amount; // Incoming transfer
        }
      }
    }
    return balance;
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AccountRepository(db);
});

final accountsStreamProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccounts();
});

final accountsWithBalancesStreamProvider = StreamProvider<List<AccountWithBalance>>((ref) {
  // Trigger update when transactions change as well
  ref.watch(appDatabaseProvider);
  return ref.watch(accountRepositoryProvider).watchAccountsWithBalances();
});
