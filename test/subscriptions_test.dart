import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/database/app_database.dart';
import 'package:lumina_expense/features/subscriptions/data/subscription_repository.dart';
import 'package:lumina_expense/features/transactions/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late SubscriptionRepository subRepo;
  late TransactionRepository txRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    subRepo = SubscriptionRepository(db);
    txRepo = TransactionRepository(db);

    // Seed test accounts & categories
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: 'acc-bank',
        name: 'Bank Checking',
        type: 'bank',
        initialBalance: const drift.Value(2000.0),
      ),
    );

    await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        id: 'cat-ent',
        name: 'Entertainment',
        type: 'expense',
      ),
    );

    await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        id: 'cat-util',
        name: 'Bills & Utilities',
        type: 'expense',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('Creates a subscription and verifies properties', () async {
    final nextDue = DateTime.now().add(const Duration(days: 10));
    await subRepo.createSubscription(
      RecurringTransactionsCompanion.insert(
        id: 'sub-netflix',
        title: 'Netflix Premium',
        amount: 20.0,
        categoryId: 'cat-ent',
        accountId: 'acc-bank',
        frequency: const drift.Value('monthly'),
        nextDueDate: nextDue,
        autoLog: const drift.Value(true),
        notes: const drift.Value('Family 4K plan'),
      ),
    );

    final subs = await subRepo.watchSubscriptions().first;
    expect(subs.length, 1);
    expect(subs.first.subscription.title, 'Netflix Premium');
    expect(subs.first.subscription.amount, 20.0);
    expect(subs.first.category.name, 'Entertainment');
    expect(subs.first.account.name, 'Bank Checking');
    expect(subs.first.daysUntilDue, 10);
    expect(subs.first.isOverdue, false);
    expect(subs.first.monthlyNormalizedAmount, 20.0);
    expect(subs.first.yearlyNormalizedAmount, 240.0);
  });

  test('Subscriptions summary calculates monthly burn and annual run rate correctly', () async {
    // 1. Monthly $20
    await subRepo.createSubscription(
      RecurringTransactionsCompanion.insert(
        id: 'sub-1',
        title: 'Monthly Sub',
        amount: 20.0,
        categoryId: 'cat-ent',
        accountId: 'acc-bank',
        frequency: const drift.Value('monthly'),
        nextDueDate: DateTime.now().add(const Duration(days: 5)),
      ),
    );

    // 2. Yearly $120 ($10/month)
    await subRepo.createSubscription(
      RecurringTransactionsCompanion.insert(
        id: 'sub-2',
        title: 'Annual Sub',
        amount: 120.0,
        categoryId: 'cat-util',
        accountId: 'acc-bank',
        frequency: const drift.Value('yearly'),
        nextDueDate: DateTime.now().add(const Duration(days: 3)),
      ),
    );

    final summary = await subRepo.watchSubscriptionsSummary().first;
    expect(summary.activeCount, 2);
    expect(summary.totalMonthlyBurn, 30.0); // 20 + 10 = 30
    expect(summary.totalYearlyBurn, 360.0); // 30 * 12 = 360
    expect(summary.upcomingThisWeekCount, 2); // Both due in 5 and 3 days
  });

  test('calculateNextDueDate advances dates accurately for frequencies', () {
    final baseDate = DateTime(2026, 1, 15, 10, 0);

    // Monthly
    final nextMonth = subRepo.calculateNextDueDate(baseDate, 'monthly', 1);
    expect(nextMonth.year, 2026);
    expect(nextMonth.month, 2);
    expect(nextMonth.day, 15);

    // Yearly
    final nextYear = subRepo.calculateNextDueDate(baseDate, 'yearly', 1);
    expect(nextYear.year, 2027);
    expect(nextYear.month, 1);
    expect(nextYear.day, 15);

    // Weekly
    final nextWeek = subRepo.calculateNextDueDate(baseDate, 'weekly', 1);
    expect(nextWeek.difference(baseDate).inDays, 7);
  });

  test('Logging a subscription payment records transaction and advances due date', () async {
    final initialDue = DateTime(2026, 3, 10);
    await subRepo.createSubscription(
      RecurringTransactionsCompanion.insert(
        id: 'sub-gym',
        title: 'Gym Membership',
        amount: 45.0,
        categoryId: 'cat-ent',
        accountId: 'acc-bank',
        frequency: const drift.Value('monthly'),
        nextDueDate: initialDue,
      ),
    );

    // Log payment
    await subRepo.logSubscriptionPayment('sub-gym');

    // Verify transaction recorded
    final txs = await txRepo.watchTransactionsWithDetails().first;
    expect(txs.length, 1);
    expect(txs.first.transaction.title, 'Gym Membership (Recurring)');
    expect(txs.first.transaction.amount, 45.0);

    // Verify subscription due date advanced to next month (April 10)
    final subs = await subRepo.watchSubscriptions().first;
    expect(subs.first.subscription.nextDueDate.month, 4);
    expect(subs.first.subscription.nextDueDate.day, 10);
  });

  test('Auto-log catch-up automatically processes overdue subscriptions', () async {
    // Overdue by 5 days with autoLog = true
    final pastDue = DateTime.now().subtract(const Duration(days: 5));
    await subRepo.createSubscription(
      RecurringTransactionsCompanion.insert(
        id: 'sub-autolog',
        title: 'Cloud Server Hosting',
        amount: 15.0,
        categoryId: 'cat-util',
        accountId: 'acc-bank',
        frequency: const drift.Value('monthly'),
        nextDueDate: pastDue,
        autoLog: const drift.Value(true),
      ),
    );

    final loggedCount = await subRepo.processAutoLogCatchUp();
    expect(loggedCount >= 1, true);

    final txs = await txRepo.watchTransactionsWithDetails().first;
    expect(txs.length, 1);
    expect(txs.first.transaction.title, 'Cloud Server Hosting (Auto-log)');

    final subs = await subRepo.watchSubscriptions().first;
    expect(subs.first.subscription.nextDueDate.isAfter(DateTime.now()), true);
  });
}
