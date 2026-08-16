import 'dart:math' as math;

import 'package:drift/drift.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

enum ActionType {
  reduceSspending,
  increaseSavings,
  payDebt,
  setBudget,
  diversify,
}

enum InsightPriority {
  high,
  medium,
  low,
}

class HealthInsight {
  final String title;
  final String description;
  final IconData icon;
  final InsightPriority priority;
  final ActionType actionType;

  HealthInsight({
    required this.title,
    required this.description,
    required this.icon,
    required this.priority,
    required this.actionType,
  });
}

class FinancialHealthReport {
  final double overallScore;
  final double savingsRateScore;
  final double budgetScore;
  final double consistencyScore;
  final double trendScore;
  final double debtScore;
  final String grade;
  final Color gradeColor;
  final List<HealthInsight> insights;

  FinancialHealthReport({
    required this.overallScore,
    required this.savingsRateScore,
    required this.budgetScore,
    required this.consistencyScore,
    required this.trendScore,
    required this.debtScore,
    required this.grade,
    required this.gradeColor,
    required this.insights,
  });
}

class FinancialHealthService {
  final AppDatabase _db;

  FinancialHealthService(this._db);

  Future<FinancialHealthReport> calculateHealthScore() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOf3MonthsAgo = DateTime(now.year, now.month - 3, 1);

    // 1. Savings Rate (30% weight)
    final thisMonthIncome = await _getSumForType('income', startOfMonth, now);
    final thisMonthExpense = await _getSumForType('expense', startOfMonth, now);

    double savingsRate = 0.0;
    if (thisMonthIncome > 0) {
      savingsRate = (thisMonthIncome - thisMonthExpense) / thisMonthIncome;
    } else if (thisMonthExpense > 0) {
      savingsRate = -1.0;
    }

    // Savings Rate Score = min(100, (savings_rate / 0.20) * 100)
    double savingsRateScore = 0.0;
    if (savingsRate > 0) {
      savingsRateScore = (savingsRate / 0.20) * 100;
      if (savingsRateScore > 100) savingsRateScore = 100;
    }

    // 2. Budget Adherence (25% weight)
    final budgets = await _db.select(_db.budgets).get();
    double budgetScore = 0.0;
    bool hasBudgets = budgets.isNotEmpty;
    bool budgetExceeded = false;
    String? exceededCategoryName;

    if (hasBudgets) {
      double totalBudgetScore = 0.0;
      for (var budget in budgets) {
        final spent = await _getSumForCategory(budget.categoryId, startOfMonth, now);
        double remainingPct = 0.0;
        if (budget.amountLimit > 0) {
          remainingPct = (budget.amountLimit - spent) / budget.amountLimit;
        }

        if (spent > budget.amountLimit * 0.8) {
          budgetExceeded = true;
          final cat = await (_db.select(_db.categories)
                ..where((c) => c.id.equals(budget.categoryId)))
              .getSingleOrNull();
          if (cat != null) exceededCategoryName = cat.name;
        }

        double currentBudgetScore = remainingPct * 100;
        if (currentBudgetScore < 0) currentBudgetScore = 0;
        if (currentBudgetScore > 100) currentBudgetScore = 100;

        totalBudgetScore += currentBudgetScore;
      }
      budgetScore = totalBudgetScore / budgets.length;
    } else {
      budgetScore = 50.0; // neutral if no budgets
    }

    // 3. Expense Consistency (20% weight)
    final dailyExpenses = await _getDailyExpenses(startOfMonth, now);
    double consistencyScore = 100.0;
    bool highVariance = false;
    if (dailyExpenses.length > 1) {
      final mean = dailyExpenses.reduce((a, b) => a + b) / dailyExpenses.length;
      if (mean > 0) {
        final variance = dailyExpenses
                .map((x) => (x - mean) * (x - mean))
                .reduce((a, b) => a + b) /
            dailyExpenses.length;
        final stdDev = math.sqrt(variance);
        final cov = stdDev / mean;

        // Consistency Score = 100 - min(100, coefficient_of_variation * 100)
        consistencyScore = 100 - (cov * 100);
        if (consistencyScore < 0) consistencyScore = 0;

        if (cov > 0.8) highVariance = true;
      }
    }

    // 4. Income vs Expense Trend (15% weight)
    final inc3mo = await _getSumForType('income', startOf3MonthsAgo, startOfMonth);
    final exp3mo = await _getSumForType('expense', startOf3MonthsAgo, startOfMonth);

    double trendScore = 50.0; // neutral default
    bool expenseCreep = false;

    if (inc3mo > 0 && exp3mo > 0 && thisMonthIncome > 0 && thisMonthExpense > 0) {
      final oldRatio = exp3mo / inc3mo;
      final newRatio = thisMonthExpense / thisMonthIncome;

      if (newRatio < oldRatio) {
        trendScore = 80.0 + ((oldRatio - newRatio) * 100);
        if (trendScore > 100) trendScore = 100;
      } else {
        trendScore = 50.0 - ((newRatio - oldRatio) * 100);
        if (trendScore < 0) trendScore = 0;
        if (newRatio - oldRatio > 0.1) expenseCreep = true;
      }
    } else if (inc3mo == 0 && thisMonthIncome > 0) {
      trendScore = 100.0;
    } else if (exp3mo > 0 && thisMonthExpense < exp3mo / 2) {
      trendScore = 75.0;
    }

    // 5. Debt Health (10% weight)
    final debts = await (_db.select(_db.debts)
          ..where((d) => d.type.equals('borrowed'))
          ..where((d) => d.isSettled.equals(false)))
        .get();
    double totalDebt = debts.fold(0.0, (sum, d) => sum + (d.amount - d.settledAmount));

    double safeIncome = thisMonthIncome > 0 ? thisMonthIncome : 1.0;
    double debtRatio = totalDebt / safeIncome;
    double debtScore = 100 - (debtRatio * 50);
    if (debtScore < 0) debtScore = 0;
    if (debtScore > 100) debtScore = 100;

    // Calculate Overall
    final overallScore = (savingsRateScore * 0.30) +
        (budgetScore * 0.25) +
        (consistencyScore * 0.20) +
        (trendScore * 0.15) +
        (debtScore * 0.10);

    // Grade Mapping
    String grade;
    Color gradeColor;
    if (overallScore >= 90) {
      grade = 'A+';
      gradeColor = const Color(0xFF10B981);
    } else if (overallScore >= 80) {
      grade = 'A';
      gradeColor = const Color(0xFF34D399);
    } else if (overallScore >= 70) {
      grade = 'B+';
      gradeColor = const Color(0xFF3B82F6);
    } else if (overallScore >= 60) {
      grade = 'B';
      gradeColor = const Color(0xFF60A5FA);
    } else if (overallScore >= 50) {
      grade = 'C+';
      gradeColor = const Color(0xFFF59E0B);
    } else if (overallScore >= 40) {
      grade = 'C';
      gradeColor = const Color(0xFFFBBF24);
    } else if (overallScore >= 30) {
      grade = 'D';
      gradeColor = const Color(0xFFEF4444);
    } else {
      grade = 'F';
      gradeColor = const Color(0xFFDC2626);
    }

    // Insights Generation
    List<HealthInsight> insights = [];

    if (savingsRate < 0.10) {
      insights.add(HealthInsight(
        title: 'Boost Your Savings',
        description:
            'Your savings rate is below 10%. Try cutting back on non-essential spending to build a safety net.',
        icon: Icons.savings_outlined,
        priority: InsightPriority.high,
        actionType: ActionType.increaseSavings,
      ));
    } else if (savingsRate >= 0.20) {
      insights.add(HealthInsight(
        title: 'Super Saver',
        description:
            'Great job! You are saving 20%+ of your income. Keep up the fantastic work.',
        icon: Icons.star_border,
        priority: InsightPriority.low,
        actionType: ActionType.increaseSavings,
      ));
    }

    if (budgetExceeded && exceededCategoryName != null) {
      insights.add(HealthInsight(
        title: 'Watch Budget for $exceededCategoryName',
        description:
            'You are nearing or exceeding your budget limit for $exceededCategoryName.',
        icon: Icons.warning_amber_rounded,
        priority: InsightPriority.medium,
        actionType: ActionType.reduceSspending,
      ));
    }

    if (!hasBudgets) {
      insights.add(HealthInsight(
        title: 'Set Up Budgets',
        description:
            'Setting budgets can help you track spending and avoid going overboard.',
        icon: Icons.account_balance_wallet_outlined,
        priority: InsightPriority.low,
        actionType: ActionType.setBudget,
      ));
    }

    if (highVariance) {
      insights.add(HealthInsight(
        title: 'Smooth Out Spending Spikes',
        description:
            'Your daily spending varies a lot. Try to plan your large purchases better to smooth out cash flow.',
        icon: Icons.trending_flat,
        priority: InsightPriority.medium,
        actionType: ActionType.reduceSspending,
      ));
    }

    if (expenseCreep) {
      insights.add(HealthInsight(
        title: 'Expense Creep Alert',
        description:
            'Your expenses are growing faster than your income compared to the last 3 months.',
        icon: Icons.trending_up,
        priority: InsightPriority.high,
        actionType: ActionType.reduceSspending,
      ));
    }

    if (debtRatio > 0.3) {
      insights.add(HealthInsight(
        title: 'Debt Reduction Priority',
        description:
            'Your debt is high relative to your income. Consider allocating more funds to pay it off.',
        icon: Icons.money_off,
        priority: InsightPriority.high,
        actionType: ActionType.payDebt,
      ));
    } else if (totalDebt == 0 && insights.length < 3) {
      insights.add(HealthInsight(
        title: 'Debt Free',
        description:
            'You have no outstanding borrowed debts. Enjoy the financial freedom!',
        icon: Icons.celebration_outlined,
        priority: InsightPriority.low,
        actionType: ActionType.diversify,
      ));
    }

    // Ensure at least one positive insight
    if (overallScore > 70 && !insights.any((i) => i.priority == InsightPriority.low)) {
      insights.add(HealthInsight(
        title: 'Financially Healthy',
        description: 'You are maintaining good financial habits across the board.',
        icon: Icons.thumb_up_outlined,
        priority: InsightPriority.low,
        actionType: ActionType.diversify,
      ));
    }

    return FinancialHealthReport(
      overallScore: overallScore,
      savingsRateScore: savingsRateScore,
      budgetScore: budgetScore,
      consistencyScore: consistencyScore,
      trendScore: trendScore,
      debtScore: debtScore,
      grade: grade,
      gradeColor: gradeColor,
      insights: insights,
    );
  }

  Future<double> _getSumForType(String type, DateTime start, DateTime end) async {
    final query = _db.select(_db.transactions)
      ..where((t) => t.type.equals(type))
      ..where((t) => t.date.isBiggerOrEqualValue(start))
      ..where((t) => t.date.isSmallerOrEqualValue(end));
    final txs = await query.get();
    return txs.fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  Future<double> _getSumForCategory(String categoryId, DateTime start, DateTime end) async {
    final query = _db.select(_db.transactions)
      ..where((t) => t.categoryId.equals(categoryId))
      ..where((t) => t.type.equals('expense'))
      ..where((t) => t.date.isBiggerOrEqualValue(start))
      ..where((t) => t.date.isSmallerOrEqualValue(end));
    final txs = await query.get();
    return txs.fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  Future<List<double>> _getDailyExpenses(DateTime start, DateTime end) async {
    final query = _db.select(_db.transactions)
      ..where((t) => t.type.equals('expense'))
      ..where((t) => t.date.isBiggerOrEqualValue(start))
      ..where((t) => t.date.isSmallerOrEqualValue(end));
    final txs = await query.get();

    final map = <int, double>{};
    for (var t in txs) {
      final day = t.date.day;
      map[day] = (map[day] ?? 0) + t.amount;
    }
    return map.values.toList();
  }
}

final financialHealthProvider = FutureProvider.autoDispose<FinancialHealthReport>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return FinancialHealthService(db).calculateHealthScore();
});
