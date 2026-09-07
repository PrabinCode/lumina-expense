import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';

enum HealthTier {
  thriving, // 90 - 100
  strong, // 75 - 89
  fair, // 60 - 74
  needsAttention, // 45 - 59
  atRisk, // 0 - 44
}

extension HealthTierX on HealthTier {
  String get label {
    switch (this) {
      case HealthTier.thriving:
        return 'Thriving';
      case HealthTier.strong:
        return 'Strong';
      case HealthTier.fair:
        return 'Fair';
      case HealthTier.needsAttention:
        return 'Needs Attention';
      case HealthTier.atRisk:
        return 'At Risk';
    }
  }

  String get icon {
    switch (this) {
      case HealthTier.thriving:
        return '🌟';
      case HealthTier.strong:
        return '🟢';
      case HealthTier.fair:
        return '🔵';
      case HealthTier.needsAttention:
        return '🟡';
      case HealthTier.atRisk:
        return '🔴';
    }
  }

  Color get color {
    switch (this) {
      case HealthTier.thriving:
        return const Color(0xFF10B981); // Emerald
      case HealthTier.strong:
        return const Color(0xFF14B8A6); // Teal
      case HealthTier.fair:
        return const Color(0xFF3B82F6); // Blue
      case HealthTier.needsAttention:
        return const Color(0xFFF59E0B); // Amber
      case HealthTier.atRisk:
        return const Color(0xFFEF4444); // Coral Red
    }
  }

  String get headline {
    switch (this) {
      case HealthTier.thriving:
        return 'Elite Financial Freedom';
      case HealthTier.strong:
        return 'Solid Financial Foundation';
      case HealthTier.fair:
        return 'Balanced with Room to Grow';
      case HealthTier.needsAttention:
        return 'Cash Flow Under Pressure';
      case HealthTier.atRisk:
        return 'High Financial Stress Zone';
    }
  }

  String get description {
    switch (this) {
      case HealthTier.thriving:
        return 'Your income comfortably exceeds spending with exceptional savings rate and negligible high-interest debt.';
      case HealthTier.strong:
        return 'You maintain healthy cash flow reserves, dependable budget discipline, and manageable financial obligations.';
      case HealthTier.fair:
        return 'You are breaking even or building modest savings. A few targeted improvements will elevate you to Strong.';
      case HealthTier.needsAttention:
        return 'Expenses are outpacing recommended benchmarks or debt burdens are consuming too much monthly liquidity.';
      case HealthTier.atRisk:
        return 'You are spending faster than income or carrying elevated debt. Immediate spending adjustments are strongly advised.';
    }
  }
}

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

class PillarMetric {
  final String id;
  final String title;
  final IconData icon;
  final double score; // 0.0 to 100.0
  final double weight; // e.g. 0.30
  final String statusLabel; // 'Excellent', 'Good', 'Fair', 'Needs Work', 'Not Set Up'
  final Color statusColor;
  final String headline; // e.g. "Saved 24.5% of income"
  final String explanation; // Plain-English explanation
  final String benchmark; // e.g. "Golden Rule: Save at least 20% of monthly income"
  final String recommendation; // Tailored advice
  final Map<String, String> keyMetrics; // Real numbers table
  final String? actionLabel; // Button text
  final String? actionRoute; // 'budgets', 'debts', 'goals', 'add_transaction'
  final bool isConfigured;

  PillarMetric({
    required this.id,
    required this.title,
    required this.icon,
    required this.score,
    required this.weight,
    required this.statusLabel,
    required this.statusColor,
    required this.headline,
    required this.explanation,
    required this.benchmark,
    required this.recommendation,
    required this.keyMetrics,
    this.actionLabel,
    this.actionRoute,
    this.isConfigured = true,
  });

  String get weightLabel => '${(weight * 100).toInt()}% weight';
}

class HealthActionTask {
  final String title;
  final String impact; // e.g. "+15 to +25 pts"
  final Color impactColor;
  final String description;
  final String actionLabel;
  final String actionRoute; // 'budgets', 'debts', 'goals', 'add_transaction'
  final IconData icon;

  HealthActionTask({
    required this.title,
    required this.impact,
    required this.impactColor,
    required this.description,
    required this.actionLabel,
    required this.actionRoute,
    required this.icon,
  });
}

class FinancialHealthReport {
  final double overallScore;
  final HealthTier tier;
  final String grade; // Backward-compatible letter grade: 'A+', 'A', 'B', etc.
  final Color gradeColor;
  final String summarySentence;
  final String nextMilestoneLabel;
  final int pointsToNextMilestone;
  final List<PillarMetric> pillars;
  final List<HealthActionTask> actionRoadmap;
  final List<HealthInsight> insights;
  final double monthlyIncome;
  final double monthlyExpense;
  final double netSaved;
  final double savingsRate;

  FinancialHealthReport({
    required this.overallScore,
    required this.tier,
    required this.grade,
    required this.gradeColor,
    required this.summarySentence,
    required this.nextMilestoneLabel,
    required this.pointsToNextMilestone,
    required this.pillars,
    required this.actionRoadmap,
    required this.insights,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.netSaved,
    required this.savingsRate,
  });

  // Backward-compatible getters
  double get savingsRateScore => _getPillarScore('savings_rate');
  double get budgetScore => _getPillarScore('budget_adherence');
  double get consistencyScore => _getPillarScore('consistency');
  double get trendScore => _getPillarScore('cash_flow_trend');
  double get debtScore => _getPillarScore('debt_freedom');

  double _getPillarScore(String id) {
    for (final p in pillars) {
      if (p.id == id) return p.score;
    }
    return 50.0;
  }
}

class FinancialHealthService {
  final AppDatabase _db;

  FinancialHealthService(this._db);

  Future<FinancialHealthReport> calculateHealthScore() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOf3MonthsAgo = DateTime(now.year, now.month - 3, 1);

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Savings Rate Pillar (30% weight)
    // ─────────────────────────────────────────────────────────────────────────
    final thisMonthIncome = await _getSumForType('income', startOfMonth, now);
    final thisMonthExpense = await _getSumForType('expense', startOfMonth, now);
    final netSaved = thisMonthIncome - thisMonthExpense;

    double savingsRate = 0.0;
    if (thisMonthIncome > 0) {
      savingsRate = netSaved / thisMonthIncome;
    } else if (thisMonthExpense > 0) {
      savingsRate = -1.0;
    }

    double savingsRateScore = 0.0;
    if (savingsRate > 0) {
      // Golden benchmark is saving >= 20% of income for full 100 points
      savingsRateScore = (savingsRate / 0.20) * 100;
      if (savingsRateScore > 100) savingsRateScore = 100;
    }

    String savingsStatus;
    Color savingsColor;
    String savingsHeadline;
    String savingsExplanation;
    String savingsRecommendation;

    if (thisMonthIncome <= 0 && thisMonthExpense <= 0) {
      savingsStatus = 'No Data';
      savingsColor = Colors.grey;
      savingsHeadline = 'No income or expenses logged yet';
      savingsExplanation = 'Log your monthly income and expenses to unlock savings rate scoring.';
      savingsRecommendation = 'Add your income from salary, freelance, or business to begin.';
    } else if (thisMonthIncome <= 0) {
      savingsStatus = 'No Income';
      savingsColor = AppColors.warning;
      savingsHeadline = 'Spent ${CurrencyFormatter.format(thisMonthExpense)} with no income logged';
      savingsExplanation = 'You have logged expenses this month but no income. Without income, savings rate is 0%.';
      savingsRecommendation = 'Record your monthly income to see how much of your earnings you are keeping.';
    } else if (netSaved < 0) {
      savingsStatus = 'Deficit';
      savingsColor = AppColors.expense;
      savingsHeadline = 'Spending exceeded earnings by ${CurrencyFormatter.format(netSaved.abs())}';
      savingsExplanation = 'You spent more than you earned this month. This depletes your cash buffers.';
      savingsRecommendation = 'Audit your discretionary expenses and trim non-essentials to stop cash burn.';
    } else if (savingsRate >= 0.20) {
      savingsStatus = 'Excellent';
      savingsColor = AppColors.income;
      savingsHeadline = 'Saving ${(savingsRate * 100).toStringAsFixed(1)}% of your income';
      savingsExplanation = 'You are beating the golden 20% savings rule by keeping ${CurrencyFormatter.format(netSaved)}!';
      savingsRecommendation = 'Outstanding discipline! Channel this surplus into a high-yield Savings Goal.';
    } else if (savingsRate >= 0.10) {
      savingsStatus = 'Good';
      savingsColor = AppColors.primary;
      savingsHeadline = 'Saving ${(savingsRate * 100).toStringAsFixed(1)}% of your income';
      savingsExplanation = 'You are keeping a positive buffer. Aim for 20% to build an unbreakable safety cushion.';
      savingsRecommendation = 'Try saving an additional ${CurrencyFormatter.format((thisMonthIncome * 0.20) - netSaved)} to hit the 20% benchmark.';
    } else {
      savingsStatus = 'Low';
      savingsColor = AppColors.warning;
      savingsHeadline = 'Saving only ${(savingsRate * 100).toStringAsFixed(1)}% of your income';
      savingsExplanation = 'Your savings rate is below 10%, leaving little room for unexpected expenses.';
      savingsRecommendation = 'Review your recurring bills and dining spend to boost your savings rate above 15%.';
    }

    final savingsPillar = PillarMetric(
      id: 'savings_rate',
      title: 'Savings Discipline',
      icon: Icons.savings_outlined,
      score: savingsRateScore,
      weight: 0.30,
      statusLabel: savingsStatus,
      statusColor: savingsColor,
      headline: savingsHeadline,
      explanation: savingsExplanation,
      benchmark: 'The 50/30/20 rule recommends setting aside at least 20% of income for savings and investments.',
      recommendation: savingsRecommendation,
      keyMetrics: {
        'Monthly Income': CurrencyFormatter.format(thisMonthIncome),
        'Monthly Expenses': CurrencyFormatter.format(thisMonthExpense),
        'Net Saved': CurrencyFormatter.format(netSaved),
        'Target (20%)': CurrencyFormatter.format(thisMonthIncome * 0.20),
      },
      actionLabel: thisMonthIncome <= 0 ? 'Log Income' : 'Deposit in Goal',
      actionRoute: thisMonthIncome <= 0 ? 'add_transaction' : 'goals',
    );

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Budget Adherence Pillar (25% weight)
    // ─────────────────────────────────────────────────────────────────────────
    final budgets = await _db.select(_db.budgets).get();
    double budgetScore = 0.0;
    bool hasBudgets = budgets.isNotEmpty;
    int onTrackCount = 0;
    int exceededCount = 0;
    double totalBudgetLimit = 0.0;
    double totalBudgetSpent = 0.0;
    String? mostExceededCategory;

    if (hasBudgets) {
      double totalBudgetScore = 0.0;
      for (final budget in budgets) {
        totalBudgetLimit += budget.amountLimit;
        final spent = await _getSumForCategory(budget.categoryId, startOfMonth, now);
        totalBudgetSpent += spent;

        double currentBudgetScore = 100.0;
        if (spent > budget.amountLimit) {
          exceededCount++;
          final overshoot = (spent - budget.amountLimit) / (budget.amountLimit > 0 ? budget.amountLimit : 1.0);
          // E.g. 10% overshoot -> 80 pts; 50% overshoot -> 0 pts
          currentBudgetScore = (1.0 - (overshoot * 2.0)) * 100.0;
          if (currentBudgetScore < 0) currentBudgetScore = 0;
          if (mostExceededCategory == null) {
            final cat = await (_db.select(_db.categories)
                  ..where((c) => c.id.equals(budget.categoryId)))
                .getSingleOrNull();
            if (cat != null) mostExceededCategory = cat.name;
          }
        } else {
          onTrackCount++;
          final usageRatio = spent / (budget.amountLimit > 0 ? budget.amountLimit : 1.0);
          if (usageRatio <= 0.85) {
            currentBudgetScore = 100.0;
          } else {
            currentBudgetScore = 100.0 - ((usageRatio - 0.85) / 0.15) * 10.0;
          }
        }
        totalBudgetScore += currentBudgetScore;
      }
      budgetScore = totalBudgetScore / budgets.length;
    } else {
      budgetScore = 50.0; // neutral baseline
    }

    String budgetStatus;
    Color budgetColor;
    String budgetHeadline;
    String budgetExplanation;
    String budgetRecommendation;

    if (!hasBudgets) {
      budgetStatus = 'Not Set Up';
      budgetColor = Colors.grey;
      budgetHeadline = 'No category budgets created yet';
      budgetExplanation = 'You have not set any category limits. Budgets help you protect money before it slips away.';
      budgetRecommendation = 'Set monthly budgets for top categories (Dining, Shopping) to unlock up to +25 health points!';
    } else if (exceededCount > 0) {
      budgetStatus = '$exceededCount Exceeded';
      budgetColor = AppColors.expense;
      budgetHeadline = '$exceededCount of ${budgets.length} budgets exceeded';
      budgetExplanation = 'Overspending in ${mostExceededCategory ?? "categories"} is reducing your adherence score.';
      budgetRecommendation = 'Pause non-essential purchases in exceeded categories until the new month begins.';
    } else if (budgetScore >= 80) {
      budgetStatus = 'On Track';
      budgetColor = AppColors.income;
      budgetHeadline = 'All ${budgets.length} budgets are healthy & on track';
      budgetExplanation = 'You are respecting your planned limits, spending ${CurrencyFormatter.format(totalBudgetSpent)} of ${CurrencyFormatter.format(totalBudgetLimit)}.';
      budgetRecommendation = 'Great control! Continue monitoring your weekly pace.';
    } else {
      budgetStatus = 'Moderate';
      budgetColor = AppColors.warning;
      budgetHeadline = 'Approaching limits on some categories';
      budgetExplanation = 'You have consumed over 70% of your allocated limits with days remaining in the month.';
      budgetRecommendation = 'Monitor discretionary spend closely to avoid crossing your limits.';
    }

    final budgetPillar = PillarMetric(
      id: 'budget_adherence',
      title: 'Budget Discipline',
      icon: Icons.pie_chart_outline_rounded,
      score: budgetScore,
      weight: 0.25,
      statusLabel: budgetStatus,
      statusColor: budgetColor,
      headline: budgetHeadline,
      explanation: budgetExplanation,
      benchmark: 'Active budgets keep your monthly discretionary spending strictly predictable.',
      recommendation: budgetRecommendation,
      keyMetrics: hasBudgets
          ? {
              'Active Budgets': '${budgets.length}',
              'On Track': '$onTrackCount',
              'Exceeded': '$exceededCount',
              'Total Cap': CurrencyFormatter.format(totalBudgetLimit),
            }
          : {
              'Active Budgets': '0',
              'Tracked Limits': 'None',
              'Potential Score': '+25 pts',
            },
      actionLabel: hasBudgets ? 'Manage Budgets' : 'Set First Budget',
      actionRoute: 'budgets',
      isConfigured: hasBudgets,
    );

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Expense Consistency Pillar (20% weight)
    // ─────────────────────────────────────────────────────────────────────────
    final dailyExpenses = await _getDailyExpenses(startOfMonth, now);
    double consistencyScore = 100.0;
    double avgDailySpend = 0.0;
    double maxDaySpend = 0.0;

    if (dailyExpenses.length > 1) {
      avgDailySpend = dailyExpenses.reduce((a, b) => a + b) / dailyExpenses.length;
      maxDaySpend = dailyExpenses.reduce(math.max);

      if (avgDailySpend > 0) {
        final variance = dailyExpenses
                .map((x) => (x - avgDailySpend) * (x - avgDailySpend))
                .reduce((a, b) => a + b) /
            dailyExpenses.length;
        final stdDev = math.sqrt(variance);
        final cov = stdDev / avgDailySpend;

        consistencyScore = 100 - (cov * 100);
        if (consistencyScore < 0) consistencyScore = 0;
        if (consistencyScore > 100) consistencyScore = 100;
      }
    } else if (dailyExpenses.length == 1) {
      avgDailySpend = dailyExpenses.first;
      maxDaySpend = dailyExpenses.first;
      consistencyScore = 75.0;
    }

    String consistencyStatus;
    Color consistencyColor;
    String consistencyHeadline;
    String consistencyExplanation;

    if (consistencyScore >= 80) {
      consistencyStatus = 'Stable';
      consistencyColor = AppColors.income;
      consistencyHeadline = 'Smooth, predictable spending rhythm';
      consistencyExplanation = 'Your daily spending stays evenly distributed without volatile impulse spikes.';
    } else if (consistencyScore >= 55) {
      consistencyStatus = 'Moderate';
      consistencyColor = AppColors.primary;
      consistencyHeadline = 'Moderate day-to-day spending variance';
      consistencyExplanation = 'Occasional spikes occur. Aim to plan big purchases in advance to keep cash flow smooth.';
    } else {
      consistencyStatus = 'Volatile';
      consistencyColor = AppColors.warning;
      consistencyHeadline = 'Irregular spending spikes detected';
      consistencyExplanation = 'Large single-day purchases create volatile swings that can strain account liquidity.';
    }

    final consistencyPillar = PillarMetric(
      id: 'consistency',
      title: 'Spending Stability',
      icon: Icons.timeline_rounded,
      score: consistencyScore,
      weight: 0.20,
      statusLabel: consistencyStatus,
      statusColor: consistencyColor,
      headline: consistencyHeadline,
      explanation: consistencyExplanation,
      benchmark: 'Predictable daily spending prevents month-end liquidity shortages.',
      recommendation: 'Spread major purchases across billing cycles and buffer for irregular expenses.',
      keyMetrics: {
        'Daily Average': CurrencyFormatter.format(avgDailySpend),
        'Highest Day': CurrencyFormatter.format(maxDaySpend),
        'Days Tracked': '${dailyExpenses.length}',
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Cash Flow Trend Pillar (15% weight)
    // ─────────────────────────────────────────────────────────────────────────
    final inc3mo = await _getSumForType('income', startOf3MonthsAgo, startOfMonth);
    final exp3mo = await _getSumForType('expense', startOf3MonthsAgo, startOfMonth);

    double trendScore = 70.0;
    String trendStatus = 'Healthy';
    Color trendColor = AppColors.primary;
    String trendHeadline = 'Cash flow is holding steady';
    String trendExplanation = 'Your spending habits are consistent with your multi-month baseline.';

    if (inc3mo > 0 && exp3mo > 0 && thisMonthIncome > 0 && thisMonthExpense > 0) {
      final oldRatio = exp3mo / inc3mo;
      final newRatio = thisMonthExpense / thisMonthIncome;

      if (newRatio < oldRatio) {
        trendScore = 80.0 + ((oldRatio - newRatio) * 100);
        if (trendScore > 100) trendScore = 100;
        trendStatus = 'Improving';
        trendColor = AppColors.income;
        trendHeadline = 'Spending less of your income than recent months';
        trendExplanation = 'Your expense-to-income ratio improved compared to your 3-month trailing average.';
      } else {
        trendScore = 65.0 - ((newRatio - oldRatio) * 100);
        if (trendScore < 10) trendScore = 10;
        if (newRatio - oldRatio > 0.15) {
          trendStatus = 'Expense Creep';
          trendColor = AppColors.warning;
          trendHeadline = 'Lifestyle / Expense creep detected';
          trendExplanation = 'Your spending is eating up a larger percentage of earnings than previous months.';
        } else {
          trendStatus = 'Normal';
          trendColor = AppColors.primary;
          trendHeadline = 'Spending pace matches historical average';
        }
      }
    }

    final trendPillar = PillarMetric(
      id: 'cash_flow_trend',
      title: 'Cash Flow Momentum',
      icon: Icons.trending_up_rounded,
      score: trendScore,
      weight: 0.15,
      statusLabel: trendStatus,
      statusColor: trendColor,
      headline: trendHeadline,
      explanation: trendExplanation,
      benchmark: 'Long-term financial health requires keeping lifestyle creep in check as income changes.',
      recommendation: 'Guard your gains by increasing automated savings whenever income grows.',
      keyMetrics: {
        'This Month Burn': CurrencyFormatter.format(thisMonthExpense),
        '3-Mo Historical': CurrencyFormatter.format(exp3mo > 0 ? exp3mo / 3 : thisMonthExpense),
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Debt Freedom Pillar (10% weight)
    // ─────────────────────────────────────────────────────────────────────────
    final borrowedDebts = await (_db.select(_db.debts)
          ..where((d) => d.type.equals('borrowed'))
          ..where((d) => d.isSettled.equals(false)))
        .get();

    double totalBorrowedDue = 0.0;
    for (final d in borrowedDebts) {
      totalBorrowedDue += (d.amount - d.settledAmount);
    }

    double debtScore = 100.0;
    String debtStatus;
    Color debtColor;
    String debtHeadline;
    String debtExplanation;
    String debtRecommendation;

    if (borrowedDebts.isEmpty || totalBorrowedDue <= 0) {
      debtScore = 100.0;
      debtStatus = 'Debt Free';
      debtColor = AppColors.income;
      debtHeadline = 'Zero outstanding borrowed debt';
      debtExplanation = 'You have no active borrowed debts or IOUs. Total peace of mind!';
      debtRecommendation = 'Continue operating debt-free and keep an emergency fund for peace of mind.';
    } else {
      final safeIncome = thisMonthIncome > 0 ? thisMonthIncome : 1.0;
      final debtRatio = totalBorrowedDue / safeIncome;
      debtScore = 100 - (debtRatio * 50);
      if (debtScore < 0) debtScore = 0;
      if (debtScore > 100) debtScore = 100;

      if (debtScore >= 80) {
        debtStatus = 'Low Burden';
        debtColor = AppColors.primary;
        debtHeadline = 'Carrying ${CurrencyFormatter.format(totalBorrowedDue)} in borrowed IOUs';
        debtExplanation = 'Your borrowed balance is modest relative to your monthly cash flow.';
        debtRecommendation = 'Schedule full repayment to restore 100/100 Debt Freedom.';
      } else {
        debtStatus = 'High Debt';
        debtColor = AppColors.expense;
        debtHeadline = 'High debt burden: ${CurrencyFormatter.format(totalBorrowedDue)} due';
        debtExplanation = 'Your outstanding borrowed debts represent a significant portion of income.';
        debtRecommendation = 'Prioritize settling active IOUs to reduce financial drag.';
      }
    }

    final debtPillar = PillarMetric(
      id: 'debt_freedom',
      title: 'Debt Freedom',
      icon: Icons.handshake_outlined,
      score: debtScore,
      weight: 0.10,
      statusLabel: debtStatus,
      statusColor: debtColor,
      headline: debtHeadline,
      explanation: debtExplanation,
      benchmark: 'Zero borrowed IOUs means all your earnings stay in your pocket.',
      recommendation: debtRecommendation,
      keyMetrics: {
        'Active Debts': '${borrowedDebts.length}',
        'Total Due': CurrencyFormatter.format(totalBorrowedDue),
        'Status': borrowedDebts.isEmpty ? 'Clean' : 'Pending Pay',
      },
      actionLabel: borrowedDebts.isNotEmpty ? 'Review IOUs' : null,
      actionRoute: borrowedDebts.isNotEmpty ? 'debts' : null,
    );

    // ─────────────────────────────────────────────────────────────────────────
    // Composite Health Score & Tier
    // ─────────────────────────────────────────────────────────────────────────
    final overallScore = (savingsRateScore * 0.30) +
        (budgetScore * 0.25) +
        (consistencyScore * 0.20) +
        (trendScore * 0.15) +
        (debtScore * 0.10);

    HealthTier tier;
    String grade;
    Color gradeColor;
    String nextMilestoneLabel;
    int pointsToNextMilestone;

    if (overallScore >= 90) {
      tier = HealthTier.thriving;
      grade = 'A+';
      gradeColor = HealthTier.thriving.color;
      nextMilestoneLabel = 'Peak Perfection';
      pointsToNextMilestone = (100 - overallScore).round();
    } else if (overallScore >= 75) {
      tier = HealthTier.strong;
      grade = 'A';
      gradeColor = HealthTier.strong.color;
      nextMilestoneLabel = 'Thriving (90+)';
      pointsToNextMilestone = (90 - overallScore).round();
    } else if (overallScore >= 60) {
      tier = HealthTier.fair;
      grade = 'B';
      gradeColor = HealthTier.fair.color;
      nextMilestoneLabel = 'Strong (75+)';
      pointsToNextMilestone = (75 - overallScore).round();
    } else if (overallScore >= 45) {
      tier = HealthTier.needsAttention;
      grade = 'C';
      gradeColor = HealthTier.needsAttention.color;
      nextMilestoneLabel = 'Fair (60+)';
      pointsToNextMilestone = (60 - overallScore).round();
    } else {
      tier = HealthTier.atRisk;
      grade = 'D';
      gradeColor = HealthTier.atRisk.color;
      nextMilestoneLabel = 'Needs Attention (45+)';
      pointsToNextMilestone = (45 - overallScore).round();
    }

    final pillars = [
      savingsPillar,
      budgetPillar,
      consistencyPillar,
      trendPillar,
      debtPillar,
    ];

    // ─────────────────────────────────────────────────────────────────────────
    // Actionable Level-Up Roadmap (Top 2-3 High Impact Steps)
    // ─────────────────────────────────────────────────────────────────────────
    final actionRoadmap = <HealthActionTask>[];

    if (!hasBudgets) {
      actionRoadmap.add(HealthActionTask(
        title: 'Create Your First Monthly Budget',
        impact: '+15 to +25 pts',
        impactColor: AppColors.primary,
        description: 'Set spending limits for top categories like Dining or Shopping to unlock the Budget Discipline score.',
        actionLabel: 'Set Budget',
        actionRoute: 'budgets',
        icon: Icons.pie_chart_outline_rounded,
      ));
    } else if (exceededCount > 0 && mostExceededCategory != null) {
      actionRoadmap.add(HealthActionTask(
        title: 'Control $mostExceededCategory Overspending',
        impact: '+10 to +18 pts',
        impactColor: AppColors.warning,
        description: 'You have exceeded your monthly limit for $mostExceededCategory. Slowing down will restore budget balance.',
        actionLabel: 'View Budgets',
        actionRoute: 'budgets',
        icon: Icons.warning_amber_rounded,
      ));
    }

    if (thisMonthIncome <= 0) {
      actionRoadmap.add(HealthActionTask(
        title: 'Record Your Monthly Income',
        impact: '+20 to +30 pts',
        impactColor: AppColors.income,
        description: 'Add your salary or business earnings so the system can compute your true savings rate.',
        actionLabel: 'Log Income',
        actionRoute: 'add_transaction',
        icon: Icons.add_circle_outline_rounded,
      ));
    } else if (savingsRate < 0.20 && thisMonthIncome > 0) {
      final shortfall = (thisMonthIncome * 0.20) - netSaved;
      actionRoadmap.add(HealthActionTask(
        title: 'Hit 20% Golden Savings Rule',
        impact: '+8 to +15 pts',
        impactColor: AppColors.income,
        description: 'Save an additional ${CurrencyFormatter.format(shortfall.clamp(0, double.infinity))} to max out your savings discipline score.',
        actionLabel: 'Deposit to Goal',
        actionRoute: 'goals',
        icon: Icons.savings_outlined,
      ));
    }

    if (borrowedDebts.isNotEmpty && totalBorrowedDue > 0) {
      actionRoadmap.add(HealthActionTask(
        title: 'Pay Off Outstanding Borrowed IOUs',
        impact: '+5 to +10 pts',
        impactColor: AppColors.secondary,
        description: 'You have ${CurrencyFormatter.format(totalBorrowedDue)} in unpaid borrowed debt. Repaying unlocks 100% Debt Freedom.',
        actionLabel: 'Review IOUs',
        actionRoute: 'debts',
        icon: Icons.handshake_outlined,
      ));
    }

    // Dynamic Insights (for backward compatibility & high-level highlights)
    final insights = <HealthInsight>[];
    if (savingsRate >= 0.20) {
      insights.add(HealthInsight(
        title: 'Super Saver',
        description: 'Saving 20%+ of your earnings! You are building durable wealth.',
        icon: Icons.star_border_rounded,
        priority: InsightPriority.low,
        actionType: ActionType.increaseSavings,
      ));
    } else if (savingsRate < 0.10 && thisMonthIncome > 0) {
      insights.add(HealthInsight(
        title: 'Boost Savings Cushion',
        description: 'Your savings rate is below 10%. Try tucking away a bit more into savings goals.',
        icon: Icons.savings_outlined,
        priority: InsightPriority.high,
        actionType: ActionType.increaseSavings,
      ));
    }

    if (!hasBudgets) {
      insights.add(HealthInsight(
        title: 'Set Category Budgets',
        description: 'Active budgets unlock up to +25 points on your health score.',
        icon: Icons.pie_chart_outline_rounded,
        priority: InsightPriority.medium,
        actionType: ActionType.setBudget,
      ));
    } else if (exceededCount > 0) {
      insights.add(HealthInsight(
        title: 'Budget Overrun',
        description: '$exceededCount category budgets are currently exceeded.',
        icon: Icons.warning_amber_rounded,
        priority: InsightPriority.high,
        actionType: ActionType.reduceSspending,
      ));
    }

    if (borrowedDebts.isEmpty) {
      insights.add(HealthInsight(
        title: '100% Debt Free',
        description: 'No outstanding borrowed IOUs. Financial peace of mind!',
        icon: Icons.celebration_outlined,
        priority: InsightPriority.low,
        actionType: ActionType.payDebt,
      ));
    }

    String summarySentence;
    switch (tier) {
      case HealthTier.thriving:
        summarySentence = 'Your financial health is in top shape! Income substantially outpaces spending with healthy reserves.';
        break;
      case HealthTier.strong:
        summarySentence = 'Solid foundation! You are consistently keeping spending in check and building financial buffer.';
        break;
      case HealthTier.fair:
        summarySentence = 'Balanced position. Cash flow is steady, and a few small adjustments will level you up to Strong.';
        break;
      case HealthTier.needsAttention:
        summarySentence = 'Cash flow is tight this month. Trimming discretionary spending will quickly restore your score.';
        break;
      case HealthTier.atRisk:
        summarySentence = 'Expenses are running ahead of income. Review your high-spend categories to stabilize your cash flow.';
        break;
    }

    return FinancialHealthReport(
      overallScore: overallScore,
      tier: tier,
      grade: grade,
      gradeColor: gradeColor,
      summarySentence: summarySentence,
      nextMilestoneLabel: nextMilestoneLabel,
      pointsToNextMilestone: pointsToNextMilestone,
      pillars: pillars,
      actionRoadmap: actionRoadmap,
      insights: insights,
      monthlyIncome: thisMonthIncome,
      monthlyExpense: thisMonthExpense,
      netSaved: netSaved,
      savingsRate: savingsRate,
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
    final directTxs = await (_db.select(_db.transactions)
          ..where((t) =>
              t.categoryId.equals(categoryId) &
              t.type.equals('expense') &
              t.isSplit.equals(false) &
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerOrEqualValue(end)))
        .get();
    final directSpent = directTxs.fold<double>(0.0, (sum, t) => sum + t.amount);

    final splitRows = await (_db.select(_db.transactionSplits).join([
      innerJoin(_db.transactions, _db.transactions.id.equalsExp(_db.transactionSplits.transactionId)),
    ])
          ..where(_db.transactionSplits.categoryId.equals(categoryId) &
              _db.transactions.type.equals('expense') &
              _db.transactions.date.isBiggerOrEqualValue(start) &
              _db.transactions.date.isSmallerOrEqualValue(end)))
        .get();

    final splitSpent = splitRows.fold<double>(
      0.0,
      (sum, row) => sum + row.readTable(_db.transactionSplits).amount,
    );

    return directSpent + splitSpent;
  }

  Future<List<double>> _getDailyExpenses(DateTime start, DateTime end) async {
    final query = _db.select(_db.transactions)
      ..where((t) => t.type.equals('expense'))
      ..where((t) => t.date.isBiggerOrEqualValue(start))
      ..where((t) => t.date.isSmallerOrEqualValue(end));
    final txs = await query.get();

    final map = <int, double>{};
    for (final t in txs) {
      final day = t.date.day;
      map[day] = (map[day] ?? 0) + t.amount;
    }
    return map.values.toList();
  }
}

final financialHealthProvider = StreamProvider.autoDispose<FinancialHealthReport>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.transactions).watch().asyncMap((_) async {
    return FinancialHealthService(db).calculateHealthScore();
  });
});
