import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../transactions/data/transaction_repository.dart';
import '../../domain/models/analytics_models.dart';

class SmartInsightsCard extends ConsumerWidget {
  final FinancialSummaryComparison? comparison;
  final List<CategorySpending> categories;
  final List<CategoryTrendItem> categoryTrends;
  final List<DayOfWeekSpending> dayOfWeeks;
  final List<TopMerchantItem> topMerchants;
  final TimeframePeriod currentPeriod;

  const SmartInsightsCard({
    super.key,
    this.comparison,
    this.categories = const [],
    this.categoryTrends = const [],
    this.dayOfWeeks = const [],
    this.topMerchants = const [],
    required this.currentPeriod,
  });

  /// Factory helper that automatically wires live Drift streams from [transactionRepositoryProvider].
  static Widget live({
    required DateTime startDate,
    required DateTime endDate,
    required DateTime prevStartDate,
    required DateTime prevEndDate,
    required TimeframePeriod currentPeriod,
  }) {
    return Consumer(
      builder: (context, ref, _) {
        final repo = ref.watch(transactionRepositoryProvider);
        return StreamBuilder<FinancialSummaryComparison>(
          stream: repo.watchSummaryComparison(startDate, endDate, prevStartDate, prevEndDate),
          builder: (context, comparisonSnap) {
            return StreamBuilder<List<CategorySpending>>(
              stream: repo.watchCategorySpending(startDate, endDate),
              builder: (context, catSnap) {
                return StreamBuilder<List<CategoryTrendItem>>(
                  stream: repo.watchCategoryMoMTrends(startDate),
                  builder: (context, trendSnap) {
                    return StreamBuilder<List<DayOfWeekSpending>>(
                      stream: repo.watchDayOfWeekDistribution(startDate, endDate),
                      builder: (context, dowSnap) {
                        return StreamBuilder<List<TopMerchantItem>>(
                          stream: repo.watchTopMerchants(startDate, endDate),
                          builder: (context, merchSnap) {
                            return SmartInsightsCard(
                              comparison: comparisonSnap.data,
                              categories: catSnap.data ?? const [],
                              categoryTrends: trendSnap.data ?? const [],
                              dayOfWeeks: dowSnap.data ?? const [],
                              topMerchants: merchSnap.data ?? const [],
                              currentPeriod: currentPeriod,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  List<SmartInsight> _generateInsights() {
    final insights = <SmartInsight>[];

    final cur = comparison?.current;
    if (cur == null || (cur.totalIncome == 0 && cur.totalExpense == 0)) {
      return insights;
    }

    // 1. Savings Rate / Surplus Insight
    final savings = cur.netSavings;
    final income = cur.totalIncome;
    final savingsRate = income > 0 ? (savings / income) * 100 : 0.0;

    if (savingsRate >= 20) {
      insights.add(
        SmartInsight(
          title: 'Strong Savings Habit 🎯',
          message: 'You have preserved ${savingsRate.toStringAsFixed(1)}% of your income (${CurrencyFormatter.format(savings)}) this ${currentPeriod.label.toLowerCase()}.',
          type: InsightType.positive,
        ),
      );
    } else if (savings < 0) {
      insights.add(
        SmartInsight(
          title: 'Spending Exceeded Income ⚠️',
          message: 'Total outflow exceeded income by ${CurrencyFormatter.format(savings.abs())}. Consider reviewing flexible categories.',
          type: InsightType.warning,
        ),
      );
    } else if (savingsRate > 0) {
      insights.add(
        SmartInsight(
          title: 'Positive Cash Flow ✓',
          message: 'Net surplus of ${CurrencyFormatter.format(savings)} (${savingsRate.toStringAsFixed(1)}% savings rate) retained.',
          type: InsightType.positive,
        ),
      );
    }

    // 2. Category Trend Spike Anomaly
    if (categoryTrends.isNotEmpty) {
      final spikes = categoryTrends
          .where((t) => t.isIncreased && t.percentageDelta >= 15 && t.currentAmount >= 30)
          .toList()
        ..sort((a, b) => b.percentageDelta.compareTo(a.percentageDelta));

      if (spikes.isNotEmpty) {
        final topSpike = spikes.first;
        insights.add(
          SmartInsight(
            title: '${topSpike.category.name} Surge 📈',
            message: 'Outflow jumped +${topSpike.percentageDelta.toStringAsFixed(0)}% compared to the previous period (${CurrencyFormatter.format(topSpike.currentAmount)} vs ${CurrencyFormatter.format(topSpike.previousAmount)}).',
            type: InsightType.anomaly,
            categoryName: topSpike.category.name,
          ),
        );
      }
    }

    // 3. Dominant Expense Category
    if (categories.isNotEmpty) {
      final topCat = categories.first;
      if (topCat.percentage >= 25 && topCat.totalAmount > 0) {
        insights.add(
          SmartInsight(
            title: '${topCat.category.name} is #1 Outflow 🏷️',
            message: 'Accounts for ${topCat.percentage.toStringAsFixed(0)}% of your total expenses (${CurrencyFormatter.format(topCat.totalAmount)}).',
            type: InsightType.neutral,
            categoryName: topCat.category.name,
          ),
        );
      }
    }

    // 4. Peak Day of Week
    if (dayOfWeeks.isNotEmpty) {
      final days = List<DayOfWeekSpending>.from(dayOfWeeks)..sort((a, b) => b.amount.compareTo(a.amount));
      final peakDay = days.first;
      if (peakDay.percentage >= 22 && peakDay.amount > 0) {
        insights.add(
          SmartInsight(
            title: 'Peak Spending: ${peakDay.dayName} 📅',
            message: '${peakDay.percentage.toStringAsFixed(0)}% of spending occurred on ${peakDay.dayName}s (${CurrencyFormatter.format(peakDay.amount)}).',
            type: InsightType.neutral,
          ),
        );
      }
    }

    // 5. Top Merchant
    if (topMerchants.isNotEmpty) {
      final topM = topMerchants.first;
      if (topM.transactionCount >= 2 && topM.totalAmount > 0) {
        insights.add(
          SmartInsight(
            title: '${topM.name} Frequent Stop 🏪',
            message: '${topM.transactionCount} transactions recorded totaling ${CurrencyFormatter.format(topM.totalAmount)}.',
            type: InsightType.neutral,
          ),
        );
      }
    }

    return insights;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final insights = _generateInsights();

    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF8B5CF6), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        'Smart Insights Radar',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${insights.length} active',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: insights.map((insight) {
              Color badgeColor;
              IconData badgeIcon;

              switch (insight.type) {
                case InsightType.positive:
                  badgeColor = AppColors.income;
                  badgeIcon = Icons.trending_up_rounded;
                  break;
                case InsightType.warning:
                  badgeColor = AppColors.expense;
                  badgeIcon = Icons.warning_amber_rounded;
                  break;
                case InsightType.anomaly:
                  badgeColor = AppColors.warning;
                  badgeIcon = Icons.show_chart_rounded;
                  break;
                case InsightType.neutral:
                  badgeColor = const Color(0xFF3B82F6);
                  badgeIcon = Icons.insights_rounded;
                  break;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(badgeIcon, color: badgeColor, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight.title,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            insight.message,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
