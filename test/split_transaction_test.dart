import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/database/app_database.dart';
import 'package:lumina_expense/features/budgets/data/budget_repository.dart';
import 'package:lumina_expense/features/transactions/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository txRepo;
  late BudgetRepository budgetRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    txRepo = TransactionRepository(db);
    budgetRepo = BudgetRepository(db);

    // Seed test accounts & categories
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: 'acc-1',
        name: 'Main Checking',
        type: 'bank',
        initialBalance: const drift.Value(1000.0),
      ),
    );

    await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        id: 'cat-groceries',
        name: 'Groceries',
        type: 'expense',
      ),
    );

    await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        id: 'cat-dining',
        name: 'Food & Dining',
        type: 'expense',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('Creates a split transaction atomically with split items', () async {
    const txId = 'split-tx-1';
    final txCompanion = TransactionsCompanion.insert(
      id: txId,
      title: 'Costco Superstore & Food Court',
      amount: 100.0,
      type: 'expense',
      accountId: 'acc-1',
      isSplit: const drift.Value(true),
    );

    final splits = [
      TransactionSplitsCompanion.insert(
        id: 'split-item-1',
        transactionId: txId,
        categoryId: 'cat-groceries',
        amount: 70.0,
        note: const drift.Value('Groceries section'),
      ),
      TransactionSplitsCompanion.insert(
        id: 'split-item-2',
        transactionId: txId,
        categoryId: 'cat-dining',
        amount: 30.0,
        note: const drift.Value('Food court lunch'),
      ),
    ];

    await txRepo.createTransactionWithSplits(txCompanion, splits);

    final txList = await txRepo.watchTransactionsWithDetails().first;
    expect(txList.length, 1);
    expect(txList.first.transaction.isSplit, true);
    expect(txList.first.splits.length, 2);
    expect(txList.first.splits[0].split.amount, 70.0);
    expect(txList.first.splits[0].category.name, 'Groceries');
    expect(txList.first.splits[1].split.amount, 30.0);
    expect(txList.first.splits[1].category.name, 'Food & Dining');
  });

  test('Category spending breakdown accounts for split items correctly', () async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // Direct grocery transaction $50
    await txRepo.createTransaction(
      TransactionsCompanion.insert(
        id: 'direct-tx',
        title: 'Local Grocer',
        amount: 50.0,
        type: 'expense',
        categoryId: const drift.Value('cat-groceries'),
        accountId: 'acc-1',
        date: drift.Value(now),
      ),
    );

    // Split transaction $100 -> $60 Groceries + $40 Dining
    const splitTxId = 'split-tx-spending';
    await txRepo.createTransactionWithSplits(
      TransactionsCompanion.insert(
        id: splitTxId,
        title: 'Big Supercenter',
        amount: 100.0,
        type: 'expense',
        accountId: 'acc-1',
        isSplit: const drift.Value(true),
        date: drift.Value(now),
      ),
      [
        TransactionSplitsCompanion.insert(
          id: 'sp-1',
          transactionId: splitTxId,
          categoryId: 'cat-groceries',
          amount: 60.0,
        ),
        TransactionSplitsCompanion.insert(
          id: 'sp-2',
          transactionId: splitTxId,
          categoryId: 'cat-dining',
          amount: 40.0,
        ),
      ],
    );

    final spending = await txRepo.watchCategorySpending(start, end).first;

    // Total expense = $150. Groceries = $50 + $60 = $110. Dining = $40.
    final grocerySpending = spending.firstWhere((s) => s.category.id == 'cat-groceries');
    final diningSpending = spending.firstWhere((s) => s.category.id == 'cat-dining');

    expect(grocerySpending.totalAmount, 110.0);
    expect(diningSpending.totalAmount, 40.0);
  });

  test('Budget progress correctly includes split transaction allocations', () async {
    final now = DateTime.now();

    // Create a $200 budget for Groceries
    await budgetRepo.createBudget(
      BudgetsCompanion.insert(
        id: 'b-groceries',
        categoryId: 'cat-groceries',
        amountLimit: 200.0,
      ),
    );

    // Create split transaction: $150 total -> $120 to Groceries
    const splitTxId = 'split-budget-test';
    await txRepo.createTransactionWithSplits(
      TransactionsCompanion.insert(
        id: splitTxId,
        title: 'Wholesale Club',
        amount: 150.0,
        type: 'expense',
        accountId: 'acc-1',
        isSplit: const drift.Value(true),
        date: drift.Value(now),
      ),
      [
        TransactionSplitsCompanion.insert(
          id: 'sp-b1',
          transactionId: splitTxId,
          categoryId: 'cat-groceries',
          amount: 120.0,
        ),
        TransactionSplitsCompanion.insert(
          id: 'sp-b2',
          transactionId: splitTxId,
          categoryId: 'cat-dining',
          amount: 30.0,
        ),
      ],
    );

    final budgets = await budgetRepo.watchBudgetsWithProgress(now).first;
    expect(budgets.length, 1);
    expect(budgets.first.currentSpent, 120.0);
    expect(budgets.first.percentage, 60.0); // 120 / 200 = 60%
    expect(budgets.first.remaining, 80.0);
  });

  test('Deleting a split transaction cascades and deletes its split items', () async {
    const txId = 'split-to-delete';
    await txRepo.createTransactionWithSplits(
      TransactionsCompanion.insert(
        id: txId,
        title: 'To Delete',
        amount: 50.0,
        type: 'expense',
        accountId: 'acc-1',
        isSplit: const drift.Value(true),
      ),
      [
        TransactionSplitsCompanion.insert(
          id: 'sp-del-1',
          transactionId: txId,
          categoryId: 'cat-groceries',
          amount: 25.0,
        ),
        TransactionSplitsCompanion.insert(
          id: 'sp-del-2',
          transactionId: txId,
          categoryId: 'cat-dining',
          amount: 25.0,
        ),
      ],
    );

    var splits = await db.select(db.transactionSplits).get();
    expect(splits.length, 2);

    await txRepo.deleteTransaction(txId);

    splits = await db.select(db.transactionSplits).get();
    expect(splits.isEmpty, true);
  });
}
