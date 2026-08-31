import '../../../../core/database/app_database.dart';

enum TimeframePeriod {
  week,
  month,
  quarter,
  year;

  String get label {
    switch (this) {
      case TimeframePeriod.week:
        return 'Week';
      case TimeframePeriod.month:
        return 'Month';
      case TimeframePeriod.quarter:
        return 'Quarter';
      case TimeframePeriod.year:
        return 'Year';
    }
  }
}

class CashFlowMonthlyPoint {
  final DateTime month;
  final double income;
  final double expense;
  final double netSavings;

  const CashFlowMonthlyPoint({
    required this.month,
    required this.income,
    required this.expense,
    required this.netSavings,
  });
}

class SpendingVelocityData {
  final int daysInMonth;
  final int currentDay;
  final List<double> currentMonthCumulative;
  final List<double> previousMonthCumulative;
  final double totalBudgetLimit;
  final double dailyAverageSpend;
  final double projectedMonthEndSpend;

  const SpendingVelocityData({
    required this.daysInMonth,
    required this.currentDay,
    required this.currentMonthCumulative,
    required this.previousMonthCumulative,
    required this.totalBudgetLimit,
    required this.dailyAverageSpend,
    required this.projectedMonthEndSpend,
  });
}

class Macro503020Summary {
  final double totalIncome;
  final double totalExpense;
  final double needsSpent;
  final double wantsSpent;
  final double savingsTransferred;

  const Macro503020Summary({
    required this.totalIncome,
    required this.totalExpense,
    required this.needsSpent,
    required this.wantsSpent,
    required this.savingsTransferred,
  });

  double get needsPercent => totalIncome > 0 ? (needsSpent / totalIncome) * 100 : 0.0;
  double get wantsPercent => totalIncome > 0 ? (wantsSpent / totalIncome) * 100 : 0.0;
  double get savingsPercent => totalIncome > 0 ? (savingsTransferred / totalIncome) * 100 : 0.0;
}

class CategoryTrendItem {
  final Category category;
  final double currentAmount;
  final double previousAmount;
  final double percentageDelta; // e.g. +15.5 or -8.2
  final bool isIncreased;

  const CategoryTrendItem({
    required this.category,
    required this.currentAmount,
    required this.previousAmount,
    required this.percentageDelta,
    required this.isIncreased,
  });
}

class DayOfWeekSpending {
  final int dayIndex; // 1 = Mon, 7 = Sun
  final String dayName;
  final double amount;
  final double percentage;

  const DayOfWeekSpending({
    required this.dayIndex,
    required this.dayName,
    required this.amount,
    required this.percentage,
  });
}

class TagSpendingItem {
  final String tag;
  final double amount;
  final int count;

  const TagSpendingItem({
    required this.tag,
    required this.amount,
    required this.count,
  });
}

class TopMerchantItem {
  final String name;
  final double totalAmount;
  final int transactionCount;
  final String? categoryIcon;
  final int? categoryColor;

  const TopMerchantItem({
    required this.name,
    required this.totalAmount,
    required this.transactionCount,
    this.categoryIcon,
    this.categoryColor,
  });
}
