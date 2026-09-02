import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/database/app_database.dart';
import 'package:lumina_expense/core/providers/database_provider.dart';
import 'package:lumina_expense/features/accounts/data/account_repository.dart';
import 'package:lumina_expense/features/budgets/data/budget_repository.dart';
import 'package:lumina_expense/features/health/data/financial_health_service.dart';
import 'package:lumina_expense/features/transactions/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('accountsWithBalancesStreamProvider updates dynamically when transactions are added', () async {
    final accountRepo = container.read(accountRepositoryProvider);
    final accounts = await accountRepo.getAllAccounts();
    final bank = accounts.firstWhere((a) => a.name == 'Bank Account');

    final emissions = <List<AccountWithBalance>>[];
    final sub = container.listen(
      accountsWithBalancesStreamProvider,
      (previous, next) {
        if (next.hasValue) {
          emissions.add(next.value!);
        }
      },
      fireImmediately: true,
    );

    // Wait for initial emission
    await pumpEventQueue();
    expect(emissions.isNotEmpty, isTrue);
    expect(emissions.last.firstWhere((a) => a.account.id == bank.id).currentBalance, 0.0);

    // 1. Add income (+2500)
    final txRepo = container.read(transactionRepositoryProvider);
    await txRepo.createTransaction(
      TransactionsCompanion.insert(
        id: 'tx-sync-1',
        title: 'Salary Deposit',
        amount: 2500.0,
        type: 'income',
        accountId: bank.id,
      ),
    );

    await pumpEventQueue();
    expect(emissions.last.firstWhere((a) => a.account.id == bank.id).currentBalance, 2500.0);

    // 2. Add expense (-300)
    await txRepo.createTransaction(
      TransactionsCompanion.insert(
        id: 'tx-sync-2',
        title: 'Groceries',
        amount: 300.0,
        type: 'expense',
        accountId: bank.id,
      ),
    );

    await pumpEventQueue();
    expect(emissions.last.firstWhere((a) => a.account.id == bank.id).currentBalance, 2200.0);

    sub.close();
  });

  test('currentMonthBudgetsProvider updates dynamically when an expense transaction is added', () async {
    final budgetRepo = container.read(budgetRepositoryProvider);
    final txRepo = container.read(transactionRepositoryProvider);
    final accountRepo = container.read(accountRepositoryProvider);

    final categories = await db.select(db.categories).get();
    final foodCategory = categories.firstWhere((c) => c.name == 'Food & Dining');
    final accounts = await accountRepo.getAllAccounts();
    final cash = accounts.firstWhere((a) => a.name == 'Cash Wallet');

    // Create a budget for Food & Dining of $500
    await budgetRepo.createBudget(
      BudgetsCompanion.insert(
        id: 'b-sync-1',
        categoryId: foodCategory.id,
        amountLimit: 500.0,
      ),
    );

    final emissions = <List<BudgetWithProgress>>[];
    final sub = container.listen(
      currentMonthBudgetsProvider,
      (previous, next) {
        if (next.hasValue) {
          emissions.add(next.value!);
        }
      },
      fireImmediately: true,
    );

    // Wait for initial emission
    await pumpEventQueue();
    expect(emissions.isNotEmpty, isTrue);
    final initialFood = emissions.last.firstWhere((b) => b.category.id == foodCategory.id);
    expect(initialFood.currentSpent, 0.0);
    expect(initialFood.percentage, 0.0);

    // Add expense transaction for Food
    await txRepo.createTransaction(
      TransactionsCompanion.insert(
        id: 'tx-budget-1',
        title: 'Dinner',
        amount: 100.0,
        type: 'expense',
        categoryId: Value(foodCategory.id),
        accountId: cash.id,
        date: Value(DateTime.now()),
      ),
    );

    await pumpEventQueue();
    final updatedFood = emissions.last.firstWhere((b) => b.category.id == foodCategory.id);
    expect(updatedFood.currentSpent, 100.0);
    expect(updatedFood.percentage, 20.0);

    sub.close();
  });

  test('financialHealthProvider updates dynamically when transactions are added', () async {
    final txRepo = container.read(transactionRepositoryProvider);
    final accountRepo = container.read(accountRepositoryProvider);

    final accounts = await accountRepo.getAllAccounts();
    final bank = accounts.firstWhere((a) => a.name == 'Bank Account');

    final emissions = <FinancialHealthReport>[];
    final sub = container.listen(
      financialHealthProvider,
      (previous, next) {
        if (next.hasValue) {
          emissions.add(next.value!);
        }
      },
      fireImmediately: true,
    );

    await pumpEventQueue();
    expect(emissions.isNotEmpty, isTrue);

    // Add income and expenses
    await txRepo.createTransaction(
      TransactionsCompanion.insert(
        id: 'tx-health-1',
        title: 'Salary',
        amount: 5000.0,
        type: 'income',
        accountId: bank.id,
      ),
    );

    await pumpEventQueue();
    expect(emissions.length, greaterThanOrEqualTo(2));

    sub.close();
  });
}
