import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/models/analytics_models.dart';

class CashFlowBarChart extends StatefulWidget {
  final List<CashFlowMonthlyPoint> points;

  const CashFlowBarChart({
    super.key,
    required this.points,
  });

  @override
  State<CashFlowBarChart> createState() => _CashFlowBarChartState();
}

class _CashFlowBarChartState extends State<CashFlowBarChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.points.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: const Text('No cash flow history available', style: TextStyle(color: Colors.grey)),
      );
    }

    double maxY = 0;
    for (final p in widget.points) {
      if (p.income > maxY) maxY = p.income;
      if (p.expense > maxY) maxY = p.expense;
    }
    maxY = (maxY * 1.2).ceilToDouble();
    if (maxY == 0) maxY = 1000;

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
                    Icon(Icons.bar_chart_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '6-Month Cash Flow',
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
                  _buildLegendIndicator('Income', AppColors.income),
                  const SizedBox(width: 8),
                  _buildLegendIndicator('Expense', AppColors.expense),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : Colors.white,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final point = widget.points[group.x.toInt()];
                      final isIncome = rodIndex == 0;
                      final monthName = DateFormat('MMM yyyy').format(point.month);
                      final val = isIncome ? point.income : point.expense;

                      return BarTooltipItem(
                        '$monthName\n${isIncome ? "Income" : "Expense"}: ${CurrencyFormatter.format(val)}',
                        TextStyle(
                          color: isIncome ? AppColors.income : AppColors.expense,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions || response == null || response.spot == null) {
                        _touchedIndex = -1;
                      } else {
                        _touchedIndex = response.spot!.touchedBarGroupIndex;
                      }
                    });
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (val, meta) {
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
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= widget.points.length) return const SizedBox.shrink();
                        final p = widget.points[idx];
                        final isTouched = idx == _touchedIndex;

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('MMM').format(p.month),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isTouched ? FontWeight.bold : FontWeight.w500,
                              color: isTouched
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
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: isDark ? Colors.white10 : Colors.black12,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(widget.points.length, (i) {
                  final p = widget.points[i];
                  final isTouched = i == _touchedIndex;

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: p.income,
                        color: AppColors.income,
                        width: isTouched ? 12 : 9,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: p.expense,
                        color: AppColors.expense,
                        width: isTouched ? 12 : 9,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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

  Widget _buildLegendIndicator(String label, Color color) {
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
