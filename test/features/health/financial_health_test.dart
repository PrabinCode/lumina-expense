import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/database/app_database.dart';
import 'package:lumina_expense/features/accounts/data/account_repository.dart';
import 'package:lumina_expense/features/budgets/data/budget_repository.dart';
import 'package:lumina_expense/features/debts/data/debt_repository.dart';
import 'package:lumina_expense/features/health/data/financial_health_service.dart';
import 'package:lumina_expense/features/transactions/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accountRepo;
  late TransactionRepository transactionRepo;
  late BudgetRepository budgetRepo;
  late DebtRepository debtRepo;
  late FinancialHealthService healthService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    accountRepo = AccountRepository(db);
    transactionRepo = TransactionRepository(db);
    budgetRepo = BudgetRepository(db);
    debtRepo = DebtRepository(db);
    healthService = FinancialHealthService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('HealthTier Extension Tests', () {
    test('Correct tier labels and icons are returned', () {
      expect(HealthTier.thriving.label, 'Thriving');
      expect(HealthTier.thriving.icon, '🌟');
      expect(HealthTier.strong.label, 'Strong');
      expect(HealthTier.fair.label, 'Fair');
      expect(HealthTier.needsAttention.label, 'Needs Attention');
      expect(HealthTier.atRisk.label, 'At Risk');
    });

    test('Tier headlines and descriptions are non-empty', () {
      for (final tier in HealthTier.values) {
        expect(tier.headline.isNotEmpty, isTrue);
        expect(tier.description.isNotEmpty, isTrue);
      }
    });
  });

  group('Financial Health Service & Report Tests', () {
    test('Initial empty database generates valid baseline report with coaching roadmap', () async {
      final report = await healthService.calculateHealthScore();

      expect(report.overallScore, greaterThanOrEqualTo(0.0));
      expect(report.overallScore, lessThanOrEqualTo(100.0));
      expect(report.tier, isNotNull);
      expect(report.pillars.length, 5);

      // Verify all 5 pillar IDs exist
      final pillarIds = report.pillars.map((p) => p.id).toSet();
      expect(
        pillarIds,
        containsAll([
          'savings_rate',
          'budget_adherence',
          'debt_freedom',
          'cash_flow_trend',
          'consistency',
        ]),
      );

      // Verify backward-compatible getters
      expect(report.savingsRateScore, isNotNull);
      expect(report.budgetScore, isNotNull);
      expect(report.consistencyScore, isNotNull);
      expect(report.trendScore, isNotNull);
      expect(report.debtScore, isNotNull);
      expect(report.grade.isNotEmpty, isTrue);
      expect(report.gradeColor, isNotNull);

      // Verify unconfigured budget pillar prompts for setup in roadmap
      final budgetPillar = report.pillars.firstWhere((p) => p.id == 'budget_adherence');
      expect(budgetPillar.isConfigured, isFalse);

      final hasBudgetRoadmapTask = report.actionRoadmap.any((t) => t.actionRoute == 'budgets');
      expect(hasBudgetRoadmapTask, isTrue);
    });

    test('Healthy income and savings elevate score into Strong/Thriving tier', () async {
      final accounts = await accountRepo.getAllAccounts();
      final bankAcc = accounts.first;
      final now = DateTime.now();

      // Income: Rs. 100,000
      await transactionRepo.createTransaction(
        TransactionsCompanion.insert(
          id: 'salary_1',
          title: 'Monthly Salary',
          amount: 100000.0,
          type: 'income',
          accountId: bankAcc.id,
          date: Value(DateTime(now.year, now.month, 2)),
        ),
      );

      // Moderate expense: Rs. 30,000 (Savings rate = 70%)
      await transactionRepo.createTransaction(
        TransactionsCompanion.insert(
          id: 'rent_1',
          title: 'Apartment Rent',
          amount: 30000.0,
          type: 'expense',
          accountId: bankAcc.id,
          date: Value(DateTime(now.year, now.month, 5)),
        ),
      );

      final report = await healthService.calculateHealthScore();

      expect(report.monthlyIncome, 100000.0);
      expect(report.monthlyExpense, 30000.0);
      expect(report.netSaved, 70000.0);
      expect(report.savingsRate, closeTo(0.70, 0.01));

      final savingsPillar = report.pillars.firstWhere((p) => p.id == 'savings_rate');
      expect(savingsPillar.score, greaterThanOrEqualTo(85.0));
      expect(savingsPillar.statusLabel, 'Excellent');

      // Key metrics table includes income and net saved
      expect(savingsPillar.keyMetrics.containsKey('Monthly Income'), isTrue);
      expect(savingsPillar.keyMetrics.containsKey('Net Saved'), isTrue);
    });

    test('Configuring and adhering to budgets awards high budget adherence score', () async {
      final accounts = await accountRepo.getAllAccounts();
      final bankAcc = accounts.first;
      final categories = await db.select(db.categories).get();
      final foodCategory = categories.first;
      final now = DateTime.now();

      // Create budget for category
      await budgetRepo.createBudget(
        BudgetsCompanion.insert(
          id: 'b_food',
          categoryId: foodCategory.id,
          amountLimit: 15000.0,
        ),
      );

      // Spend within budget (Rs. 8,000 out of Rs. 15,000)
      await transactionRepo.createTransaction(
        TransactionsCompanion.insert(
          id: 'tx_food_1',
          title: 'Groceries',
          amount: 8000.0,
          type: 'expense',
          accountId: bankAcc.id,
          categoryId: Value(foodCategory.id),
          date: Value(DateTime(now.year, now.month, 3)),
        ),
      );

      final report = await healthService.calculateHealthScore();
      final budgetPillar = report.pillars.firstWhere((p) => p.id == 'budget_adherence');

      expect(budgetPillar.isConfigured, isTrue);
      expect(budgetPillar.score, greaterThanOrEqualTo(80.0));
      expect(budgetPillar.statusLabel, 'On Track');
    });

    test('High debt obligation reduces debt score and surfaces in roadmap', () async {
      final accounts = await accountRepo.getAllAccounts();
      final bankAcc = accounts.first;
      final now = DateTime.now();

      // Modest income: Rs. 20,000
      await transactionRepo.createTransaction(
        TransactionsCompanion.insert(
          id: 'income_small',
          title: 'Freelance',
          amount: 20000.0,
          type: 'income',
          accountId: bankAcc.id,
          date: Value(DateTime(now.year, now.month, 1)),
        ),
      );

      // Huge outstanding debt: Rs. 150,000
      await debtRepo.createDebt(
        DebtsCompanion.insert(
          id: 'debt_large',
          personName: 'Apex Bank',
          amount: 150000.0,
          type: 'borrowed',
          dueDate: Value(now.add(const Duration(days: 30))),
        ),
      );

      final report = await healthService.calculateHealthScore();
      final debtPillar = report.pillars.firstWhere((p) => p.id == 'debt_freedom');

      expect(debtPillar.score, lessThan(60.0));
      expect(report.actionRoadmap.any((t) => t.actionRoute == 'debts'), isTrue);
    });

    test('Milestone progression correctly reflects points needed to next tier', () async {
      final report = await healthService.calculateHealthScore();

      if (report.tier != HealthTier.thriving) {
        expect(report.pointsToNextMilestone, greaterThan(0));
        expect(report.nextMilestoneLabel.isNotEmpty, isTrue);
      } else {
        expect(report.pointsToNextMilestone, 0);
      }
    });
  });
}
