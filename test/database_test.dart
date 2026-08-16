import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/database/app_database.dart';
import 'package:lumina_expense/features/accounts/data/account_repository.dart';
import 'package:lumina_expense/features/budgets/data/budget_repository.dart';
import 'package:lumina_expense/features/debts/data/debt_repository.dart';
import 'package:lumina_expense/features/transactions/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accountRepo;
  late TransactionRepository transactionRepo;
  late BudgetRepository budgetRepo;
  late DebtRepository debtRepo;

  setUp(() {
    // In-memory isolated database for tests
    db = AppDatabase(NativeDatabase.memory());
    accountRepo = AccountRepository(db);
    transactionRepo = TransactionRepository(db);
    budgetRepo = BudgetRepository(db);
    debtRepo = DebtRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Database seeds default accounts and categories', () async {
    final accounts = await accountRepo.getAllAccounts();
    expect(accounts.length, 2);
    expect(accounts.any((a) => a.name == 'Cash Wallet'), isTrue);
    expect(accounts.any((a) => a.name == 'Bank Account'), isTrue);

    final categories = await db.select(db.categories).get();
    expect(categories.length, greaterThan(10));
  });

  test('Calculates account balance accurately with Income, Expense and Transfer', () async {
    final accounts = await accountRepo.getAllAccounts();
    final cashAcc = accounts.firstWhere((a) => a.name == 'Cash Wallet');
    final bankAcc = accounts.firstWhere((a) => a.name == 'Bank Account');

    // 1. Add Income to Bank Account (+500)
    await transactionRepo.createTransaction(
      TransactionsCompanion.insert(
        id: 'tx_1',
        title: 'Salary Deposit',
        amount: 500.0,
        type: 'income',
        accountId: bankAcc.id,
      ),
    );

    // 2. Add Expense from Cash Wallet (-50)
    await transactionRepo.createTransaction(
      TransactionsCompanion.insert(
        id: 'tx_2',
        title: 'Coffee',
        amount: 50.0,
        type: 'expense',
        accountId: cashAcc.id,
      ),
    );

    // 3. Transfer from Bank to Cash ($100)
    await transactionRepo.createTransaction(
      TransactionsCompanion.insert(
        id: 'tx_3',
        title: 'ATM Withdrawal',
        amount: 100.0,
        type: 'transfer',
        accountId: bankAcc.id,
        toAccountId: Value(cashAcc.id),
      ),
    );

    // Verify Balances
    // Bank: 0 + 500 (income) - 100 (transfer out) = 400
    final bankBalance = await accountRepo.computeAccountBalance(bankAcc.id, bankAcc.initialBalance);
    expect(bankBalance, 400.0);

    // Cash: 0 - 50 (expense) + 100 (transfer in) = 50
    final cashBalance = await accountRepo.computeAccountBalance(cashAcc.id, cashAcc.initialBalance);
    expect(cashBalance, 50.0);
  });

  test('Debt recording and partial settlement works properly', () async {
    // Record lending $100 to Bob
    await debtRepo.createDebt(
      DebtsCompanion.insert(
        id: 'debt_1',
        personName: 'Bob',
        amount: 100.0,
        type: 'lent',
      ),
    );

    // Partial settlement $40
    await debtRepo.recordSettlement('debt_1', 40.0);

    final debt = await (db.select(db.debts)..where((t) => t.id.equals('debt_1'))).getSingle();
    expect(debt.settledAmount, 40.0);
    expect(debt.isSettled, isFalse);

    // Complete settlement remaining $60
    await debtRepo.recordSettlement('debt_1', 60.0);
    final settledDebt = await (db.select(db.debts)..where((t) => t.id.equals('debt_1'))).getSingle();
    expect(settledDebt.settledAmount, 100.0);
    expect(settledDebt.isSettled, isTrue);
  });

  test('Creates and tracks monthly category budget', () async {
    final categories = await db.select(db.categories).get();
    final foodCat = categories.firstWhere((c) => c.name == 'Food & Dining');

    await budgetRepo.createBudget(
      BudgetsCompanion.insert(
        id: 'b_1',
        categoryId: foodCat.id,
        amountLimit: 250.0,
      ),
    );

    final budgets = await db.select(db.budgets).get();
    expect(budgets.length, 1);
    expect(budgets.first.amountLimit, 250.0);
  });
}
