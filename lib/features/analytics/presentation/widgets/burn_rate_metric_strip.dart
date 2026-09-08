import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/models/analytics_models.dart';

class BurnRateMetricStrip extends ConsumerWidget {
  final DateTime startDate;
  final DateTime endDate;
  final double totalExpense;
  final double? budgetLimit;
  final TimeframePeriod currentPeriod;

  const BurnRateMetricStrip({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.totalExpense,
    this.budgetLimit,
    required this.currentPeriod,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    final totalDays = endDate.difference(startDate).inDays + 1;
    int daysElapsed;
    if (now.isAfter(endDate)) {
      daysElapsed = totalDays;
    } else if (now.isBefore(startDate)) {
      daysElapsed = 1;
    } else {
      daysElapsed = (now.difference(startDate).inDays + 1).clamp(1, totalDays);
    }

    final daysRemaining = (totalDays - daysElapsed).clamp(0, totalDays);
    final dailyAverage = totalExpense > 0 ? totalExpense / daysElapsed : 0.0;
    final projectedTotal = dailyAverage * totalDays;

    final hasBudget = budgetLimit != null && budgetLimit! > 0;
    final isOverBudget = hasBudget && projectedTotal > budgetLimit!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
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
                    const Icon(Icons.speed_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Flexible(
                      child: Text(
                        'Spending Velocity & Forecast',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$daysRemaining days left',
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTile(
                  title: 'Daily Burn',
                  value: '${CurrencyFormatter.format(dailyAverage)}/d',
                  sub: 'Avg past $daysElapsed d',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTile(
                  title: 'Projected Spend',
                  value: CurrencyFormatter.format(projectedTotal),
                  sub: hasBudget ? 'of ${CurrencyFormatter.format(budgetLimit!)} limit' : 'by period end',
                  valueColor: isOverBudget ? AppColors.expense : null,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTile(
                  title: 'Trajectory',
                  value: hasBudget
                      ? '${((projectedTotal / budgetLimit!) * 100).toStringAsFixed(0)}%'
                      : '$daysElapsed / $totalDays d',
                  sub: hasBudget
                      ? (isOverBudget ? 'Over Budget' : 'Safe Pace ✓')
                      : 'Days elapsed',
                  valueColor: hasBudget
                      ? (isOverBudget ? AppColors.expense : AppColors.income)
                      : null,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required String title,
    required String value,
    required String sub,
    Color? valueColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            sub,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
