import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../transactions/data/transaction_repository.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _touchedSectionIndex = -1;

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final startOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final endOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59);

    final summaryStream = ref.watch(transactionRepositoryProvider).watchSummary(startOfMonth, endOfMonth);
    final categorySpendingStream = ref.watch(transactionRepositoryProvider).watchCategorySpending(startOfMonth, endOfMonth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Analytics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Month Selector Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: _previousMonth,
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_currentMonth),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: _nextMonth,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Financial Summary Card (Income, Expense, Net)
            StreamBuilder<FinancialSummary>(
              stream: summaryStream,
              builder: (context, snapshot) {
                final income = snapshot.data?.totalIncome ?? 0.0;
                final expense = snapshot.data?.totalExpense ?? 0.0;
                final savings = snapshot.data?.netSavings ?? 0.0;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Income', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(income),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.income,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 24, width: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Expense', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(expense),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.expense,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 24, width: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Net Savings', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(savings),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: savings >= 0 ? AppColors.income : AppColors.expense,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Category Breakdown Donut Chart
            StreamBuilder<List<CategorySpending>>(
              stream: categorySpendingStream,
              builder: (context, snapshot) {
                final categories = snapshot.data ?? [];

                if (categories.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    margin: const EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.pie_chart_outline_rounded, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'No spending data for this month',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Donut Chart Container
                    Container(
                      height: 240,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  _touchedSectionIndex = -1;
                                  return;
                                }
                                _touchedSectionIndex =
                                    pieTouchResponse.touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          sectionsSpace: 2,
                          centerSpaceRadius: 45,
                          sections: List.generate(categories.length, (i) {
                            final isTouched = i == _touchedSectionIndex;
                            final radius = isTouched ? 50.0 : 42.0;
                            final item = categories[i];
                            return PieChartSectionData(
                              color: Color(item.category.color),
                              value: item.totalAmount,
                              title: '${item.percentage.toStringAsFixed(0)}%',
                              radius: radius,
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Categorical Breakdown List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = categories[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Color(item.category.color).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  IconHelper.getIcon(item.category.icon),
                                  color: Color(item.category.color),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.category.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: (item.percentage / 100).clamp(0.0, 1.0),
                                        backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                        valueColor: AlwaysStoppedAnimation(Color(item.category.color)),
                                        minHeight: 4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(item.totalAmount),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  Text(
                                    '${item.percentage.toStringAsFixed(1)}%',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
