import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/models/analytics_models.dart';

class SpendingVelocityChart extends StatelessWidget {
  final SpendingVelocityData velocity;

  const SpendingVelocityChart({
    super.key,
    required this.velocity,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double maxY = 0;
    if (velocity.currentMonthCumulative.isNotEmpty) {
      maxY = velocity.currentMonthCumulative.reduce((a, b) => a > b ? a : b);
    }
    if (velocity.previousMonthCumulative.isNotEmpty) {
      final prevMax = velocity.previousMonthCumulative.reduce((a, b) => a > b ? a : b);
      if (prevMax > maxY) maxY = prevMax;
    }
    if (velocity.totalBudgetLimit > maxY) maxY = velocity.totalBudgetLimit;
    maxY = (maxY * 1.15).ceilToDouble();
    if (maxY == 0) maxY = 500;

    final curSpots = List.generate(velocity.currentMonthCumulative.length, (i) {
      return FlSpot((i + 1).toDouble(), velocity.currentMonthCumulative[i]);
    });

    final prevSpots = List.generate(velocity.previousMonthCumulative.length, (i) {
      return FlSpot((i + 1).toDouble(), velocity.previousMonthCumulative[i]);
    });

    final budgetSpots = [
      const FlSpot(1, 0),
      FlSpot(velocity.daysInMonth.toDouble(), velocity.totalBudgetLimit),
    ];

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
                    Icon(Icons.timeline_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Spending Velocity & Pacing',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendDot('This Mo', AppColors.primary),
                  const SizedBox(width: 8),
                  _buildLegendDot('Last Mo', Colors.grey),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Pacing Metrics Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Daily Burn Rate', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        '${CurrencyFormatter.format(velocity.dailyAverageSpend)} / day',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Projected Month-End', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(velocity.projectedMonthEndSpend),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: (velocity.totalBudgetLimit > 0 &&
                                  velocity.projectedMonthEndSpend > velocity.totalBudgetLimit)
                              ? AppColors.expense
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Line Chart
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: velocity.daysInMonth.toDouble(),
                minY: 0,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : Colors.white,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final isCur = spot.barIndex == 0;
                        return LineTooltipItem(
                          'Day ${spot.x.toInt()}: ${CurrencyFormatter.format(spot.y)}',
                          TextStyle(
                            color: isCur ? AppColors.primary : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (val, _) {
                        if (val == 0 || val == maxY) return const SizedBox.shrink();
                        return Text(
                          CurrencyFormatter.compact(val),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      getTitlesWidget: (val, _) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'D${val.toInt()}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.black54,
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
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: isDark ? Colors.white10 : Colors.black12,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Current Month Cumulative Line (Primary Accent)
                  LineChartBarData(
                    spots: curSpots.isNotEmpty ? curSpots : [const FlSpot(1, 0)],
                    isCurved: curSpots.length > 1,
                    curveSmoothness: 0.2,
                    color: AppColors.primary,
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: curSpots.length == 1),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),

                  // Previous Month Cumulative Line (Muted Grey)
                  if (prevSpots.isNotEmpty)
                    LineChartBarData(
                      spots: prevSpots,
                      isCurved: prevSpots.length > 1,
                      curveSmoothness: 0.2,
                      color: Colors.grey.withValues(alpha: 0.5),
                      barWidth: 2,
                      dashArray: [5, 5],
                      dotData: FlDotData(show: prevSpots.length == 1),
                    ),


                  // Budget Pacing Target Line (Dotted Guideline)
                  if (velocity.totalBudgetLimit > 0)
                    LineChartBarData(
                      spots: budgetSpots,
                      isCurved: false,
                      color: AppColors.expense.withValues(alpha: 0.4),
                      barWidth: 1.5,
                      dashArray: [2, 4],
                      dotData: const FlDotData(show: false),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
        ),
      ],
    );
  }
}
