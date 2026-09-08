import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/database/app_database.dart';
import 'package:lumina_expense/features/backup/services/backup_restore_service.dart';
import 'package:lumina_expense/features/transactions/data/transaction_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late BackupRestoreService backupService;
  late TransactionRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    backupService = BackupRestoreService(db);
    repository = TransactionRepository(db);

    // Seed full demo data
    await backupService.seedDemoData();
  });

  tearDown(() async {
    await db.close();
  });

  test('watchMonthlyCashFlowTrend returns points with income and expenses', () async {
    final stream = repository.watchMonthlyCashFlowTrend(months: 6);
    final points = await stream.first;

    expect(points.length, equals(6));
    final totalIncome = points.fold<double>(0.0, (s, p) => s + p.income);
    final totalExpense = points.fold<double>(0.0, (s, p) => s + p.expense);
    expect(totalIncome, greaterThan(0));
    expect(totalExpense, greaterThan(0));
  });

  test('watchSpendingVelocity computes cumulative spending and daily burn rate', () async {
    final now = DateTime.now();
    final stream = repository.watchSpendingVelocity(now);
    final data = await stream.first;

    expect(data.daysInMonth, greaterThanOrEqualTo(28));
    expect(data.daysInMonth, lessThanOrEqualTo(31));
  });

  test('watch50_30_20Summary calculates Needs, Wants, and Savings', () async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final end = now.add(const Duration(days: 1));

    final stream = repository.watch50_30_20Summary(start, end);
    final summary = await stream.first;

    expect(summary.totalIncome, greaterThan(0));
    expect(summary.totalExpense, greaterThan(0));
    expect(summary.needsSpent, greaterThan(0));
    expect(summary.wantsSpent, greaterThan(0));
  });

  test('watchDayOfWeekDistribution returns 7 days of spending breakdown', () async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final end = now.add(const Duration(days: 1));


    final stream = repository.watchDayOfWeekDistribution(start, end);
    final dayList = await stream.first;

    expect(dayList.length, equals(7));
    expect(dayList[0].dayName, equals('Mon'));
    expect(dayList[6].dayName, equals('Sun'));
  });

  test('watchTagAnalytics aggregates spending by hashtag', () async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final end = now.add(const Duration(days: 1));

    final stream = repository.watchTagAnalytics(start, end);
    final tags = await stream.first;

    expect(tags.isNotEmpty, isTrue);
    expect(tags.any((t) => t.tag.startsWith('#')), isTrue);
  });

  test('watchTopMerchants ranks top payees by spending', () async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final end = now.add(const Duration(days: 1));

    final stream = repository.watchTopMerchants(start, end, limit: 5);
    final merchants = await stream.first;

    expect(merchants.isNotEmpty, isTrue);
    expect(merchants.first.totalAmount, greaterThanOrEqualTo(merchants.last.totalAmount));
  });

  test('watchSummaryComparison correctly computes deltas between periods', () async {
    final now = DateTime.now();
    final curStart = DateTime(now.year, now.month, 1);
    final curEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final prevStart = DateTime(now.year, now.month - 1, 1);
    final prevEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

    final stream = repository.watchSummaryComparison(curStart, curEnd, prevStart, prevEnd);
    final comparison = await stream.first;

    expect(comparison.current, isNotNull);
    expect(comparison.previous, isNotNull);
    expect(comparison.incomeDeltaPercent, isA<double>());
    expect(comparison.expenseDeltaPercent, isA<double>());
    expect(comparison.savingsDeltaPercent, isA<double>());
  });
}

