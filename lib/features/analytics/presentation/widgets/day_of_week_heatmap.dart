import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/models/analytics_models.dart';

class DayOfWeekHeatmap extends StatelessWidget {
  final List<DayOfWeekSpending> dayList;

  const DayOfWeekHeatmap({
    super.key,
    required this.dayList,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double maxAmt = 0;
    DayOfWeekSpending? highestDay;

    for (final d in dayList) {
      if (d.amount > maxAmt) {
        maxAmt = d.amount;
        highestDay = d;
      }
    }
    final maxY = maxAmt > 0 ? (maxAmt * 1.25).ceilToDouble() : 100.0;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.calendar_view_week_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Day-of-Week Spending',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (highestDay != null && highestDay.amount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Peak: ${highestDay.dayName}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : Colors.white,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = dayList[group.x.toInt()];

                      return BarTooltipItem(
                        '${item.dayName}: ${CurrencyFormatter.format(item.amount)}\n(${item.percentage.toStringAsFixed(0)}%)',
                        const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      getTitlesWidget: (val, _) {
                        if (val == 0 || val == maxY) return const SizedBox.shrink();
                        return Text(
                          CurrencyFormatter.compact(val),
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= dayList.length) return const SizedBox.shrink();
                        final isPeak = highestDay != null && dayList[idx].dayIndex == highestDay.dayIndex && highestDay.amount > 0;

                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            dayList[idx].dayName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isPeak ? FontWeight.bold : FontWeight.w500,
                              color: isPeak
                                  ? AppColors.primary
                                  : (isDark ? Colors.white60 : Colors.black54),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 3,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: isDark ? Colors.white10 : Colors.black12,
                    strokeWidth: 1,
                    dashArray: [3, 3],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(dayList.length, (i) {
                  final item = dayList[i];
                  final isPeak = highestDay != null && item.dayIndex == highestDay.dayIndex && highestDay.amount > 0;

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: item.amount,
                        color: isPeak ? AppColors.primary : AppColors.primary.withValues(alpha: 0.45),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
