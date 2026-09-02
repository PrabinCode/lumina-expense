import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class RecycleBinRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  RecycleBinRepository(this._db);

  /// Watch all soft-deleted items, optionally filtered by entityType
  Stream<List<DeletedItem>> watchDeletedItems({String? entityType}) {
    final query = _db.select(_db.deletedItems);
    if (entityType != null && entityType.isNotEmpty && entityType != 'all') {
      query.where((tbl) => tbl.entityType.equals(entityType));
    }
    query.orderBy([(tbl) => OrderingTerm(expression: tbl.deletedAt, mode: OrderingMode.desc)]);
    return query.watch();
  }

  /// Watch count of deleted items for badges/indicators
  Stream<int> watchDeletedCount() {
    return _db.select(_db.deletedItems).watch().map((items) => items.length);
  }

  /// Soft-delete a transaction and its splits into Recycle Bin
  Future<String> moveTransactionToRecycleBin(String transactionId) async {
    final tx = await (_db.select(_db.transactions)..where((t) => t.id.equals(transactionId))).getSingleOrNull();
    if (tx == null) return '';

    final splits = await (_db.select(_db.transactionSplits)..where((s) => s.transactionId.equals(transactionId))).get();

    // Fetch account / category names for rich subtitle
    final account = await (_db.select(_db.accounts)..where((a) => a.id.equals(tx.accountId))).getSingleOrNull();
    final category = tx.categoryId != null
        ? await (_db.select(_db.categories)..where((c) => c.id.equals(tx.categoryId!))).getSingleOrNull()
        : null;

    final subtitleParts = <String>[];
    if (account != null) subtitleParts.add(account.name);
    if (category != null) subtitleParts.add(category.name);

    final payload = {
      'transaction': {
        'id': tx.id,
        'title': tx.title,
        'amount': tx.amount,
        'type': tx.type,
        'categoryId': tx.categoryId,
        'accountId': tx.accountId,
        'toAccountId': tx.toAccountId,
        'date': tx.date.toIso8601String(),
        'note': tx.note,
        'tags': tx.tags,
        'receiptPath': tx.receiptPath,
        'isSplit': tx.isSplit,
        'createdAt': tx.createdAt.toIso8601String(),
      },
      'splits': splits
          .map((s) => {
                'id': s.id,
                'transactionId': s.transactionId,
                'categoryId': s.categoryId,
                'amount': s.amount,
                'note': s.note,
              })
          .toList(),
    };

    final recycleId = _uuid.v4();

    await _db.transaction(() async {
      await _db.into(_db.deletedItems).insert(
            DeletedItemsCompanion.insert(
              id: recycleId,
              entityId: tx.id,
              entityType: 'transaction',
              title: tx.title,
              subtitle: Value(subtitleParts.join(' • ')),
              amount: Value(tx.amount),
              payloadJson: jsonEncode(payload),
              deletedAt: Value(DateTime.now()),
            ),
          );

      await (_db.delete(_db.transactionSplits)..where((s) => s.transactionId.equals(tx.id))).go();
      await (_db.delete(_db.transactions)..where((t) => t.id.equals(tx.id))).go();
    });

    return recycleId;
  }

  /// Batch move transactions to Recycle Bin
  Future<List<String>> moveBatchTransactionsToRecycleBin(List<String> transactionIds) async {
    final recycleIds = <String>[];
    for (final id in transactionIds) {
      final recId = await moveTransactionToRecycleBin(id);
      if (recId.isNotEmpty) recycleIds.add(recId);
    }
    return recycleIds;
  }

  /// Soft-delete a budget
  Future<String> moveBudgetToRecycleBin(String budgetId) async {
    final b = await (_db.select(_db.budgets)..where((t) => t.id.equals(budgetId))).getSingleOrNull();
    if (b == null) return '';

    final cat = await (_db.select(_db.categories)..where((c) => c.id.equals(b.categoryId))).getSingleOrNull();

    final payload = {
      'id': b.id,
      'categoryId': b.categoryId,
      'amountLimit': b.amountLimit,
      'period': b.period,
      'startDate': b.startDate.toIso8601String(),
    };

    final recycleId = _uuid.v4();

    await _db.transaction(() async {
      await _db.into(_db.deletedItems).insert(
            DeletedItemsCompanion.insert(
              id: recycleId,
              entityId: b.id,
              entityType: 'budget',
              title: '${cat?.name ?? "Category"} Budget',
              subtitle: Value('Limit: ${b.amountLimit.toStringAsFixed(2)} • ${b.period}'),
              amount: Value(b.amountLimit),
              payloadJson: jsonEncode(payload),
              deletedAt: Value(DateTime.now()),
            ),
          );

      await (_db.delete(_db.budgets)..where((t) => t.id.equals(b.id))).go();
    });

    return recycleId;
  }

  /// Soft-delete a goal
  Future<String> moveGoalToRecycleBin(String goalId) async {
    final g = await (_db.select(_db.goals)..where((t) => t.id.equals(goalId))).getSingleOrNull();
    if (g == null) return '';

    final payload = {
      'id': g.id,
      'name': g.name,
      'targetAmount': g.targetAmount,
      'currentAmount': g.currentAmount,
      'targetDate': g.targetDate?.toIso8601String(),
      'iconName': g.iconName,
      'colorValue': g.colorValue,
      'notes': g.notes,
      'isCompleted': g.isCompleted,
      'createdAt': g.createdAt.toIso8601String(),
    };

    final recycleId = _uuid.v4();

    await _db.transaction(() async {
      await _db.into(_db.deletedItems).insert(
            DeletedItemsCompanion.insert(
              id: recycleId,
              entityId: g.id,
              entityType: 'goal',
              title: g.name,
              subtitle: Value('Target: ${g.targetAmount.toStringAsFixed(2)} • Saved: ${g.currentAmount.toStringAsFixed(2)}'),
              amount: Value(g.targetAmount),
              payloadJson: jsonEncode(payload),
              deletedAt: Value(DateTime.now()),
            ),
          );

      await (_db.delete(_db.goals)..where((t) => t.id.equals(g.id))).go();
    });

    return recycleId;
  }

  /// Soft-delete a debt
  Future<String> moveDebtToRecycleBin(String debtId) async {
    final d = await (_db.select(_db.debts)..where((t) => t.id.equals(debtId))).getSingleOrNull();
    if (d == null) return '';

    final payload = {
      'id': d.id,
      'personName': d.personName,
      'amount': d.amount,
      'settledAmount': d.settledAmount,
      'type': d.type,
      'accountId': d.accountId,
      'dueDate': d.dueDate?.toIso8601String(),
      'isSettled': d.isSettled,
      'notes': d.notes,
      'createdAt': d.createdAt.toIso8601String(),
    };

    final recycleId = _uuid.v4();

    await _db.transaction(() async {
      await _db.into(_db.deletedItems).insert(
            DeletedItemsCompanion.insert(
              id: recycleId,
              entityId: d.id,
              entityType: 'debt',
              title: '${d.type == "lent" ? "Lent to" : "Borrowed from"} ${d.personName}',
              subtitle: Value('Remaining: ${(d.amount - d.settledAmount).toStringAsFixed(2)} of ${d.amount.toStringAsFixed(2)}'),
              amount: Value(d.amount),
              payloadJson: jsonEncode(payload),
              deletedAt: Value(DateTime.now()),
            ),
          );

      await (_db.delete(_db.debts)..where((t) => t.id.equals(d.id))).go();
    });

    return recycleId;
  }

  /// Soft-delete a subscription
  Future<String> moveSubscriptionToRecycleBin(String subId) async {
    final s = await (_db.select(_db.recurringTransactions)..where((t) => t.id.equals(subId))).getSingleOrNull();
    if (s == null) return '';

    final payload = {
      'id': s.id,
      'title': s.title,
      'amount': s.amount,
      'categoryId': s.categoryId,
      'accountId': s.accountId,
      'frequency': s.frequency,
      'interval': s.interval,
      'nextDueDate': s.nextDueDate.toIso8601String(),
      'autoLog': s.autoLog,
      'isActive': s.isActive,
      'notes': s.notes,
      'createdAt': s.createdAt.toIso8601String(),
    };

    final recycleId = _uuid.v4();

    await _db.transaction(() async {
      await _db.into(_db.deletedItems).insert(
            DeletedItemsCompanion.insert(
              id: recycleId,
              entityId: s.id,
              entityType: 'subscription',
              title: s.title,
              subtitle: Value('${s.amount.toStringAsFixed(2)} / ${s.frequency}'),
              amount: Value(s.amount),
              payloadJson: jsonEncode(payload),
              deletedAt: Value(DateTime.now()),
            ),
          );

      await (_db.delete(_db.recurringTransactions)..where((t) => t.id.equals(s.id))).go();
    });

    return recycleId;
  }

  /// Restore an item from the Recycle Bin by its recycle ID
  Future<bool> restoreItem(String recycleId) async {
    final item = await (_db.select(_db.deletedItems)..where((t) => t.id.equals(recycleId))).getSingleOrNull();
    if (item == null) return false;

    final data = jsonDecode(item.payloadJson) as Map<String, dynamic>;

    await _db.transaction(() async {
      switch (item.entityType) {
        case 'transaction':
          final t = data['transaction'] as Map<String, dynamic>;
          final splits = (data['splits'] as List? ?? []).cast<Map<String, dynamic>>();

          await _db.into(_db.transactions).insert(
                TransactionsCompanion.insert(
                  id: t['id'],
                  title: t['title'],
                  amount: (t['amount'] as num).toDouble(),
                  type: t['type'],
                  categoryId: Value(t['categoryId']),
                  accountId: t['accountId'],
                  toAccountId: Value(t['toAccountId']),
                  date: Value(DateTime.parse(t['date'])),
                  note: Value(t['note']),
                  tags: Value(t['tags']),
                  receiptPath: Value(t['receiptPath']),
                  isSplit: Value(t['isSplit'] ?? false),
                  createdAt: Value(DateTime.parse(t['createdAt'])),
                ),
                mode: InsertMode.insertOrReplace,
              );

          for (final s in splits) {
            await _db.into(_db.transactionSplits).insert(
                  TransactionSplitsCompanion.insert(
                    id: s['id'],
                    transactionId: s['transactionId'],
                    categoryId: s['categoryId'],
                    amount: (s['amount'] as num).toDouble(),
                    note: Value(s['note']),
                  ),
                  mode: InsertMode.insertOrReplace,
                );
          }
          break;

        case 'budget':
          await _db.into(_db.budgets).insert(
                BudgetsCompanion.insert(
                  id: data['id'],
                  categoryId: data['categoryId'],
                  amountLimit: (data['amountLimit'] as num).toDouble(),
                  period: Value(data['period'] ?? 'monthly'),
                  startDate: Value(DateTime.parse(data['startDate'])),
                ),
                mode: InsertMode.insertOrReplace,
              );
          break;

        case 'goal':
          await _db.into(_db.goals).insert(
                GoalsCompanion.insert(
                  id: data['id'],
                  name: data['name'],
                  targetAmount: (data['targetAmount'] as num).toDouble(),
                  currentAmount: Value((data['currentAmount'] as num).toDouble()),
                  targetDate: Value(data['targetDate'] != null ? DateTime.parse(data['targetDate']) : null),
                  iconName: Value(data['iconName'] ?? 'savings'),
                  colorValue: Value(data['colorValue'] ?? 0xFF10B981),
                  notes: Value(data['notes']),
                  isCompleted: Value(data['isCompleted'] ?? false),
                  createdAt: Value(DateTime.parse(data['createdAt'])),
                ),
                mode: InsertMode.insertOrReplace,
              );
          break;

        case 'debt':
          await _db.into(_db.debts).insert(
                DebtsCompanion.insert(
                  id: data['id'],
                  personName: data['personName'],
                  amount: (data['amount'] as num).toDouble(),
                  settledAmount: Value((data['settledAmount'] as num).toDouble()),
                  type: data['type'],
                  accountId: Value(data['accountId']),
                  dueDate: Value(data['dueDate'] != null ? DateTime.parse(data['dueDate']) : null),
                  isSettled: Value(data['isSettled'] ?? false),
                  notes: Value(data['notes']),
                  createdAt: Value(DateTime.parse(data['createdAt'])),
                ),
                mode: InsertMode.insertOrReplace,
              );
          break;

        case 'subscription':
          await _db.into(_db.recurringTransactions).insert(
                RecurringTransactionsCompanion.insert(
                  id: data['id'],
                  title: data['title'],
                  amount: (data['amount'] as num).toDouble(),
                  categoryId: data['categoryId'],
                  accountId: data['accountId'],
                  frequency: Value(data['frequency'] ?? 'monthly'),
                  interval: Value(data['interval'] ?? 1),
                  nextDueDate: DateTime.parse(data['nextDueDate']),
                  autoLog: Value(data['autoLog'] ?? false),
                  isActive: Value(data['isActive'] ?? true),
                  notes: Value(data['notes']),
                  createdAt: Value(DateTime.parse(data['createdAt'])),
                ),
                mode: InsertMode.insertOrReplace,
              );
          break;
      }

      await (_db.delete(_db.deletedItems)..where((t) => t.id.equals(recycleId))).go();
    });

    return true;
  }

  /// Batch restore items
  Future<int> restoreBatch(List<String> recycleIds) async {
    int count = 0;
    for (final id in recycleIds) {
      final success = await restoreItem(id);
      if (success) count++;
    }
    return count;
  }

  /// Permanently delete an item from the Recycle Bin
  Future<int> permanentlyDeleteItem(String recycleId) {
    return (_db.delete(_db.deletedItems)..where((t) => t.id.equals(recycleId))).go();
  }

  /// Permanently delete multiple items
  Future<int> permanentlyDeleteBatch(List<String> recycleIds) {
    if (recycleIds.isEmpty) return Future.value(0);
    return (_db.delete(_db.deletedItems)..where((t) => t.id.isIn(recycleIds))).go();
  }

  /// Empty all items (or by specific entityType)
  Future<int> emptyRecycleBin({String? entityType}) {
    final query = _db.delete(_db.deletedItems);
    if (entityType != null && entityType.isNotEmpty && entityType != 'all') {
      query.where((t) => t.entityType.equals(entityType));
    }
    return query.go();
  }
}

final recycleBinRepositoryProvider = Provider<RecycleBinRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return RecycleBinRepository(db);
});

final deletedItemsStreamProvider = StreamProvider.family<List<DeletedItem>, String?>((ref, type) {
  return ref.watch(recycleBinRepositoryProvider).watchDeletedItems(entityType: type);
});

final deletedItemsCountProvider = StreamProvider<int>((ref) {
  return ref.watch(recycleBinRepositoryProvider).watchDeletedCount();
});
