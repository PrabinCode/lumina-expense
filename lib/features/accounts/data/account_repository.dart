import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../profile/providers/profile_providers.dart';

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
  final String profileId;

  AccountRepository(this._db, [this.profileId = 'default_profile']);

  Stream<List<Account>> watchAllAccounts({bool includeArchived = false}) {
    final query = _db.select(_db.accounts);
    query.where((tbl) => tbl.profileId.equals(profileId));
    if (!includeArchived) {
      query.where((tbl) => tbl.isArchived.equals(false));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]);
    return query.watch();
  }

  Future<List<Account>> getAllAccounts({bool includeArchived = false}) {
    final query = _db.select(_db.accounts);
    query.where((tbl) => tbl.profileId.equals(profileId));
    if (!includeArchived) {
      query.where((tbl) => tbl.isArchived.equals(false));
    }
    return query.get();
  }

  Future<Account?> getAccountById(String id) {
    return (_db.select(_db.accounts)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<void> createAccount(AccountsCompanion account) {
    final withProfile = account.profileId.present ? account : account.copyWith(profileId: Value(profileId));
    return _db.into(_db.accounts).insert(withProfile);
  }

  Future<bool> updateAccount(AccountsCompanion account) {
    final withProfile = account.profileId.present ? account : account.copyWith(profileId: Value(profileId));
    return _db.update(_db.accounts).replace(withProfile);
  }

  Future<int> setArchived(String accountId, bool isArchived) {
    return (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(accountId))).write(
      AccountsCompanion(isArchived: Value(isArchived)),
    );
  }

  Future<int> deleteAccount(String accountId) {
    return (_db.delete(_db.accounts)..where((tbl) => tbl.id.equals(accountId))).go();
  }

  /// Returns the number of transactions linked to this account as source or destination
  Future<int> getAccountTransactionCount(String accountId) async {
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.id.count()])
      ..where(_db.transactions.accountId.equals(accountId) | _db.transactions.toAccountId.equals(accountId));
    final count = await query.map((row) => row.read(_db.transactions.id.count()) ?? 0).getSingle();
    return count;
  }

  Future<void> restoreAccount(Account account) {
    return _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            id: account.id,
            profileId: Value(account.profileId),
            name: account.name,
            type: account.type,
            currency: Value(account.currency),
            icon: Value(account.icon),
            color: Value(account.color),
            initialBalance: Value(account.initialBalance),
            isArchived: Value(account.isArchived),
            createdAt: Value(account.createdAt),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }



  /// Watch accounts with real-time computed balances (reacts to both accounts and transactions)
  Stream<List<AccountWithBalance>> watchAccountsWithBalances() {
    late StreamController<List<AccountWithBalance>> controller;
    StreamSubscription? sub1;
    StreamSubscription? sub2;

    Future<void> emitBalances() async {
      if (controller.isClosed) return;
      try {
        final accountsList = await getAllAccounts();
        final results = <AccountWithBalance>[];

        for (final acc in accountsList) {
          final balance = await computeAccountBalance(acc.id, acc.initialBalance);
          results.add(AccountWithBalance(account: acc, currentBalance: balance));
        }

        if (!controller.isClosed) {
          controller.add(results);
        }
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
        }
      }
    }

    controller = StreamController<List<AccountWithBalance>>(
      onListen: () {
        emitBalances();
        sub1 = watchAllAccounts().listen((_) => emitBalances());
        sub2 = _db.select(_db.transactions).watch().listen((_) => emitBalances());
      },
      onCancel: () async {
        await sub1?.cancel();
        await sub2?.cancel();
      },
    );

    return controller.stream;
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

  /// Watch detailed account financial stats including current month flow, all-time flow, and % share of Net Worth
  Stream<List<AccountFinancialStats>> watchAccountsFinancialStats() {
    late StreamController<List<AccountFinancialStats>> controller;
    StreamSubscription? sub1;
    StreamSubscription? sub2;

    Future<void> emitStats() async {
      if (controller.isClosed) return;
      try {
        final accountsList = await getAllAccounts();
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

        // Fetch all transactions for this profile
        final allTxs = await (_db.select(_db.transactions)
              ..where((tbl) => tbl.profileId.equals(profileId)))
            .get();

        final rawStats = <AccountFinancialStats>[];
        double totalPositiveBalances = 0.0;

        for (final acc in accountsList) {
          double balance = acc.initialBalance;
          double monthInc = 0.0;
          double monthExp = 0.0;
          double totalInc = 0.0;
          double totalExp = 0.0;
          int txCount = 0;

          for (final tx in allTxs) {
            final isSource = tx.accountId == acc.id;
            final isDest = tx.toAccountId == acc.id;
            if (!isSource && !isDest) continue;

            txCount++;

            if (tx.type == 'income' && isSource) {
              balance += tx.amount;
              totalInc += tx.amount;
              if ((tx.date.isAfter(startOfMonth) || tx.date.isAtSameMomentAs(startOfMonth)) &&
                  (tx.date.isBefore(endOfMonth) || tx.date.isAtSameMomentAs(endOfMonth))) {
                monthInc += tx.amount;
              }
            } else if (tx.type == 'expense' && isSource) {
              balance -= tx.amount;
              totalExp += tx.amount;
              if ((tx.date.isAfter(startOfMonth) || tx.date.isAtSameMomentAs(startOfMonth)) &&
                  (tx.date.isBefore(endOfMonth) || tx.date.isAtSameMomentAs(endOfMonth))) {
                monthExp += tx.amount;
              }
            } else if (tx.type == 'transfer') {
              if (isSource) {
                balance -= tx.amount;
              }
              if (isDest) {
                balance += tx.amount;
              }
            }
          }

          if (balance > 0) {
            totalPositiveBalances += balance;
          }

          rawStats.add(AccountFinancialStats(
            account: acc,
            currentBalance: balance,
            monthIncome: monthInc,
            monthExpense: monthExp,
            allTimeIncome: totalInc,
            allTimeExpense: totalExp,
            shareOfNetWorth: 0.0,
            transactionCount: txCount,
          ));
        }

        // Calculate share of Net Worth and sort by balance descending
        final results = rawStats.map((stat) {
          final share = (totalPositiveBalances > 0 && stat.currentBalance > 0)
              ? (stat.currentBalance / totalPositiveBalances) * 100
              : 0.0;
          return AccountFinancialStats(
            account: stat.account,
            currentBalance: stat.currentBalance,
            monthIncome: stat.monthIncome,
            monthExpense: stat.monthExpense,
            allTimeIncome: stat.allTimeIncome,
            allTimeExpense: stat.allTimeExpense,
            shareOfNetWorth: share,
            transactionCount: stat.transactionCount,
          );
        }).toList()
          ..sort((a, b) => b.currentBalance.compareTo(a.currentBalance));

        if (!controller.isClosed) {
          controller.add(results);
        }
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
        }
      }
    }

    controller = StreamController<List<AccountFinancialStats>>(
      onListen: () {
        emitStats();
        sub1 = watchAllAccounts().listen((_) => emitStats());
        sub2 = _db.select(_db.transactions).watch().listen((_) => emitStats());
      },
      onCancel: () async {
        await sub1?.cancel();
        await sub2?.cancel();
      },
    );

    return controller.stream;
  }
}

class AccountFinancialStats {
  final Account account;
  final double currentBalance;
  final double monthIncome;
  final double monthExpense;
  final double allTimeIncome;
  final double allTimeExpense;
  final double shareOfNetWorth;
  final int transactionCount;

  AccountFinancialStats({
    required this.account,
    required this.currentBalance,
    required this.monthIncome,
    required this.monthExpense,
    required this.allTimeIncome,
    required this.allTimeExpense,
    required this.shareOfNetWorth,
    required this.transactionCount,
  });
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return AccountRepository(db, profileId);
});

final accountsStreamProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccounts();
});

final accountsWithBalancesStreamProvider = StreamProvider<List<AccountWithBalance>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAccountsWithBalances();
});

final accountsFinancialStatsStreamProvider = StreamProvider<List<AccountFinancialStats>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAccountsFinancialStats();
});
