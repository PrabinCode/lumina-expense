import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/database/app_database.dart';
import 'package:lumina_expense/features/recycle_bin/data/recycle_bin_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

void main() {
  late AppDatabase db;
  late RecycleBinRepository recycleRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    recycleRepo = RecycleBinRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Soft delete transaction moves to recycle bin and removes from active transactions', () async {
    // 1. Insert a transaction with a split
    final now = DateTime.now();
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'tx-1',
            title: 'Weekly Groceries',
            amount: 75.50,
            type: 'expense',
            accountId: 'cash_wallet',
            date: Value(now),
            isSplit: const Value(true),
          ),
        );

    await db.into(db.transactionSplits).insert(
          TransactionSplitsCompanion.insert(
            id: 'sp-1',
            transactionId: 'tx-1',
            categoryId: 'food_dining',
            amount: 75.50,
            note: const Value('Fresh veggies'),
          ),
        );

    // 2. Soft-delete
    final recycleId = await recycleRepo.moveTransactionToRecycleBin('tx-1');
    expect(recycleId.isNotEmpty, isTrue);

    // Verify removed from active transactions
    final activeTx = await (db.select(db.transactions)..where((t) => t.id.equals('tx-1'))).getSingleOrNull();
    expect(activeTx, isNull);

    final activeSplits = await (db.select(db.transactionSplits)..where((s) => s.transactionId.equals('tx-1'))).get();
    expect(activeSplits.isEmpty, isTrue);

    // Verify exists in deleted items
    final deleted = await (db.select(db.deletedItems)..where((d) => d.id.equals(recycleId))).getSingle();
    expect(deleted.title, 'Weekly Groceries');
    expect(deleted.amount, 75.50);
    expect(deleted.entityType, 'transaction');

    // 3. Restore transaction
    final restored = await recycleRepo.restoreItem(recycleId);
    expect(restored, isTrue);

    // Verify restored back to active transactions
    final restoredTx = await (db.select(db.transactions)..where((t) => t.id.equals('tx-1'))).getSingleOrNull();
    expect(restoredTx, isNotNull);
    expect(restoredTx!.title, 'Weekly Groceries');
    expect(restoredTx.amount, 75.50);

    final restoredSplits = await (db.select(db.transactionSplits)..where((s) => s.transactionId.equals('tx-1'))).get();
    expect(restoredSplits.length, 1);
    expect(restoredSplits.first.note, 'Fresh veggies');

    // Verify removed from deleted items
    final inBinAfterRestore = await (db.select(db.deletedItems)..where((d) => d.id.equals(recycleId))).getSingleOrNull();
    expect(inBinAfterRestore, isNull);
  });

  test('Batch soft-delete, restore, and permanent deletion', () async {
    // 1. Create two transactions
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'tx-a',
            title: 'Coffee',
            amount: 4.50,
            type: 'expense',
            accountId: 'cash_wallet',
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'tx-b',
            title: 'Book',
            amount: 20.00,
            type: 'expense',
            accountId: 'cash_wallet',
          ),
        );

    // 2. Batch soft delete
    final recycleIds = await recycleRepo.moveBatchTransactionsToRecycleBin(['tx-a', 'tx-b']);
    expect(recycleIds.length, 2);

    final active = await db.select(db.transactions).get();
    expect(active.isEmpty, isTrue);

    final deleted = await db.select(db.deletedItems).get();
    expect(deleted.length, 2);

    // 3. Restore one, permanently delete the other
    await recycleRepo.restoreItem(recycleIds.first);
    await recycleRepo.permanentlyDeleteItem(recycleIds.last);

    final activeAfter = await db.select(db.transactions).get();
    expect(activeAfter.length, 1);
    expect(activeAfter.first.title, 'Coffee');

    final inBin = await db.select(db.deletedItems).get();
    expect(inBin.isEmpty, isTrue);
  });

  test('Soft-delete and restore budget, goal, and debt', () async {
    // 1. Goal
    await db.into(db.goals).insert(
          GoalsCompanion.insert(
            id: 'goal-1',
            name: 'Emergency Fund',
            targetAmount: 5000.0,
            currentAmount: const Value(1500.0),
          ),
        );

    final goalRecycleId = await recycleRepo.moveGoalToRecycleBin('goal-1');
    expect(await (db.select(db.goals)..where((g) => g.id.equals('goal-1'))).getSingleOrNull(), isNull);
    await recycleRepo.restoreItem(goalRecycleId);
    final restoredGoal = await (db.select(db.goals)..where((g) => g.id.equals('goal-1'))).getSingleOrNull();
    expect(restoredGoal, isNotNull);
    expect(restoredGoal!.name, 'Emergency Fund');
    expect(restoredGoal.currentAmount, 1500.0);

    // 2. Debt
    await db.into(db.debts).insert(
          DebtsCompanion.insert(
            id: 'debt-1',
            personName: 'Alex',
            amount: 100.0,
            type: 'lent',
          ),
        );

    final debtRecycleId = await recycleRepo.moveDebtToRecycleBin('debt-1');
    expect(await (db.select(db.debts)..where((d) => d.id.equals('debt-1'))).getSingleOrNull(), isNull);
    await recycleRepo.restoreItem(debtRecycleId);
    final restoredDebt = await (db.select(db.debts)..where((d) => d.id.equals('debt-1'))).getSingleOrNull();
    expect(restoredDebt, isNotNull);
    expect(restoredDebt!.personName, 'Alex');
  });
}
