import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../recycle_bin/data/recycle_bin_repository.dart';
import '../../../transactions/data/transaction_repository.dart';
import '../../../transactions/presentation/screens/add_transaction_sheet.dart';
import '../../domain/models/analytics_models.dart';
import '../../../../core/widgets/sonner_toast.dart';
import '../widgets/cash_flow_bar_chart.dart';
import '../widgets/category_trend_list.dart';
import '../widgets/day_of_week_heatmap.dart';
import '../widgets/macro_50_30_20_card.dart';
import '../widgets/spending_velocity_chart.dart';
import '../widgets/tag_matrix_widget.dart';
import '../widgets/top_merchants_card.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  final DateTime? initialMonth;
  const AnalyticsScreen({super.key, this.initialMonth});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late DateTime _referenceDate;
  TimeframePeriod _currentPeriod = TimeframePeriod.month;
  int _currentTabIndex = 0;
  int _touchedSectionIndex = -1;

  @override
  void initState() {
    super.initState();
    _referenceDate = widget.initialMonth ?? DateTime.now();
  }

  void _previousPeriod() {
    setState(() {
      switch (_currentPeriod) {
        case TimeframePeriod.week:
          _referenceDate = _referenceDate.subtract(const Duration(days: 7));
          break;
        case TimeframePeriod.month:
          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month - 1, 1);
          break;
        case TimeframePeriod.quarter:
          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month - 3, 1);
          break;
        case TimeframePeriod.year:
          _referenceDate = DateTime(_referenceDate.year - 1, 1, 1);
          break;
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      switch (_currentPeriod) {
        case TimeframePeriod.week:
          _referenceDate = _referenceDate.add(const Duration(days: 7));
          break;
        case TimeframePeriod.month:
          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month + 1, 1);
          break;
        case TimeframePeriod.quarter:
          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month + 3, 1);
          break;
        case TimeframePeriod.year:
          _referenceDate = DateTime(_referenceDate.year + 1, 1, 1);
          break;
      }
    });
  }

  (DateTime, DateTime) _calculateDateRange() {
    switch (_currentPeriod) {
      case TimeframePeriod.week:
        final weekday = _referenceDate.weekday;
        final startOfWeek = DateTime(_referenceDate.year, _referenceDate.month, _referenceDate.day - (weekday - 1));
        final endOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + 6, 23, 59, 59);
        return (startOfWeek, endOfWeek);

      case TimeframePeriod.month:
        final startOfMonth = DateTime(_referenceDate.year, _referenceDate.month, 1);
        final endOfMonth = DateTime(_referenceDate.year, _referenceDate.month + 1, 0, 23, 59, 59);
        return (startOfMonth, endOfMonth);

      case TimeframePeriod.quarter:
        final currentQuarter = ((_referenceDate.month - 1) / 3).floor();
        final startMonth = currentQuarter * 3 + 1;
        final startOfQuarter = DateTime(_referenceDate.year, startMonth, 1);
        final endOfQuarter = DateTime(_referenceDate.year, startMonth + 3, 0, 23, 59, 59);
        return (startOfQuarter, endOfQuarter);

      case TimeframePeriod.year:
        final startOfYear = DateTime(_referenceDate.year, 1, 1);
        final endOfYear = DateTime(_referenceDate.year, 12, 31, 23, 59, 59);
        return (startOfYear, endOfYear);
    }
  }

  String _formatRangeLabel(DateTime start, DateTime end) {
    switch (_currentPeriod) {
      case TimeframePeriod.week:
        if (start.month == end.month) {
          return '${DateFormat('MMM d').format(start)} – ${DateFormat('d, yyyy').format(end)}';
        }
        return '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';

      case TimeframePeriod.month:
        return DateFormat('MMMM yyyy').format(start);

      case TimeframePeriod.quarter:
        final quarter = ((start.month - 1) / 3).floor() + 1;
        return 'Q$quarter ${start.year} (${DateFormat('MMM').format(start)} – ${DateFormat('MMM').format(end)})';

      case TimeframePeriod.year:
        return '${start.year}';
    }
  }

  void _showCategoryTransactionsSheet(BuildContext context, Category category, DateTime startDate, DateTime endDate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rangeLabel = _formatRangeLabel(startDate, endDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color(category.color).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          IconHelper.getCategoryIcon(category.icon),
                          color: Color(category.color),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${category.name} Transactions',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              rangeLabel,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  Expanded(
                    child: StreamBuilder<List<TransactionWithDetails>>(
                      stream: ref.watch(transactionRepositoryProvider).watchTransactionsWithDetails(
                            startDate: startDate,
                            endDate: endDate,
                            categoryId: category.id,
                          ),
                      builder: (context, snapshot) {
                        final txs = snapshot.data ?? [];
                        if (txs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.receipt_long_rounded, size: 40, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(
                                  'No transactions in ${category.name} for this period',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }

                        final totalSpent = txs.fold<double>(0.0, (s, t) => s + t.transaction.amount);

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${txs.length} transaction${txs.length > 1 ? "s" : ""}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey),
                                  ),
                                  Text(
                                    'Total: ${CurrencyFormatter.format(totalSpent)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.expense),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                controller: scrollController,
                                itemCount: txs.length,
                                separatorBuilder: (context, index) => const Divider(height: 12),
                                itemBuilder: (context, index) {
                                  final item = txs[index];
                                  final tx = item.transaction;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    subtitle: Text(
                                      '${DateFormat('MMM d, yyyy').format(tx.date)} • ${item.account.name}${tx.note != null && tx.note!.isNotEmpty ? " • ${tx.note}" : ""}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '-${CurrencyFormatter.format(tx.amount)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppColors.expense,
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
                                          onSelected: (val) async {
                                            if (val == 'edit') {
                                              if (context.mounted) {
                                                await showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  backgroundColor: Colors.transparent,
                                                  builder: (_) => AddTransactionSheet(
                                                    transactionToEdit: tx,
                                                  ),
                                                );
                                              }
                                            } else if (val == 'delete') {
                                              await ref.read(recycleBinRepositoryProvider).moveTransactionToRecycleBin(tx.id);
                                              if (context.mounted) {
                                                Sonner.success(
                                                  'Moved to Trash',
                                                  description: '"${tx.title}" can be restored from Recycle Bin',
                                                );
                                              }
                                            }
                                          },
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                                                  SizedBox(width: 8),
                                                  Text('Edit'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expense),
                                                  SizedBox(width: 8),
                                                  Text('Move to Trash'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPeriodTransactionsSheet(BuildContext context, DateTime startDate, DateTime endDate, String rangeLabel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String filterQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Transactions in Period',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  rangeLabel,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search title, category, or note...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          filled: true,
                          fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (val) => setModalState(() => filterQuery = val.trim().toLowerCase()),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      Expanded(
                        child: StreamBuilder<List<TransactionWithDetails>>(
                          stream: ref.watch(transactionRepositoryProvider).watchTransactionsWithDetails(
                                startDate: startDate,
                                endDate: endDate,
                              ),
                          builder: (context, snapshot) {
                            final allTxs = snapshot.data ?? [];
                            final txs = filterQuery.isEmpty
                                ? allTxs
                                : allTxs.where((t) {
                                    final matchTitle = t.transaction.title.toLowerCase().contains(filterQuery);
                                    final matchCat = t.category?.name.toLowerCase().contains(filterQuery) ?? false;
                                    final matchNote = t.transaction.note?.toLowerCase().contains(filterQuery) ?? false;
                                    return matchTitle || matchCat || matchNote;
                                  }).toList();

                            if (txs.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.search_off_rounded, size: 40, color: Colors.grey),
                                    const SizedBox(height: 8),
                                    Text(
                                      filterQuery.isNotEmpty
                                          ? 'No transactions match "$filterQuery"'
                                          : 'No transactions recorded for this period',
                                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final totalExpense = txs.where((t) => t.transaction.type == 'expense').fold<double>(0.0, (s, t) => s + t.transaction.amount);
                            final totalIncome = txs.where((t) => t.transaction.type == 'income').fold<double>(0.0, (s, t) => s + t.transaction.amount);

                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${txs.length} transactions',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey),
                                      ),
                                      Row(
                                        children: [
                                          if (totalIncome > 0)
                                            Text(
                                              '+${CurrencyFormatter.format(totalIncome)}  ',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.income),
                                            ),
                                          Text(
                                            '-${CurrencyFormatter.format(totalExpense)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.expense),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView.separated(
                                    controller: scrollController,
                                    itemCount: txs.length,
                                    separatorBuilder: (context, index) => const Divider(height: 12),
                                    itemBuilder: (context, index) {
                                      final item = txs[index];
                                      final tx = item.transaction;
                                      final cat = item.category;
                                      final isIncome = tx.type == 'income';

                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: cat != null
                                                ? Color(cat.color).withValues(alpha: 0.15)
                                                : (isIncome ? AppColors.income.withValues(alpha: 0.15) : AppColors.expense.withValues(alpha: 0.15)),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            IconHelper.getCategoryIcon(cat?.icon ?? (isIncome ? 'payments' : 'shopping_bag')),
                                            color: cat != null ? Color(cat.color) : (isIncome ? AppColors.income : AppColors.expense),
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                        subtitle: Text(
                                          '${DateFormat('MMM d, yyyy').format(tx.date)} • ${cat?.name ?? (isIncome ? "Income" : "Expense")} • ${item.account.name}',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${isIncome ? "+" : "-"}${CurrencyFormatter.format(tx.amount)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isIncome ? AppColors.income : AppColors.expense,
                                              ),
                                            ),
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
                                              onSelected: (val) async {
                                                if (val == 'edit') {
                                                  if (context.mounted) {
                                                    await showModalBottomSheet(
                                                      context: context,
                                                      isScrollControlled: true,
                                                      backgroundColor: Colors.transparent,
                                                      builder: (_) => AddTransactionSheet(
                                                        transactionToEdit: tx,
                                                      ),
                                                    );
                                                  }
                                                } else if (val == 'delete') {
                                                  await ref.read(recycleBinRepositoryProvider).moveTransactionToRecycleBin(tx.id);
                                                  if (context.mounted) {
                                                    Sonner.success(
                                                      'Moved to Trash',
                                                      description: '"${tx.title}" can be restored from Recycle Bin',
                                                    );
                                                  }
                                                }
                                              },
                                              itemBuilder: (ctx) => [
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                                                      SizedBox(width: 8),
                                                      Text('Edit'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expense),
                                                      SizedBox(width: 8),
                                                      Text('Move to Trash'),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (startDate, endDate) = _calculateDateRange();
    final rangeLabel = _formatRangeLabel(startDate, endDate);

    final summaryStream = ref.watch(transactionRepositoryProvider).watchSummary(startDate, endDate);
    final categorySpendingStream = ref.watch(transactionRepositoryProvider).watchCategorySpending(startDate, endDate);
    final cashFlowStream = ref.watch(transactionRepositoryProvider).watchMonthlyCashFlowTrend(months: 6);
    final dayOfWeekStream = ref.watch(transactionRepositoryProvider).watchDayOfWeekDistribution(startDate, endDate);
    final macro503020Stream = ref.watch(transactionRepositoryProvider).watch50_30_20Summary(startDate, endDate);
    final categoryTrendsStream = ref.watch(transactionRepositoryProvider).watchCategoryMoMTrends(_referenceDate);
    final tagsStream = ref.watch(transactionRepositoryProvider).watchTagAnalytics(startDate, endDate);
    final velocityStream = ref.watch(transactionRepositoryProvider).watchSpendingVelocity(_referenceDate);
    final merchantsStream = ref.watch(transactionRepositoryProvider).watchTopMerchants(startDate, endDate);


    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'Browse Transactions in Period',
            onPressed: () => _showPeriodTransactionsSheet(context, startDate, endDate, rangeLabel),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeframe Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Row(
                children: TimeframePeriod.values.map((p) {
                  final isSelected = _currentPeriod == p;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _currentPeriod = p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            p.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

            // Date Range Navigation Bar
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
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    onPressed: _previousPeriod,
                    tooltip: 'Previous',
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        rangeLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    onPressed: _nextPeriod,
                    tooltip: 'Next',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Financial Summary Card with Savings Rate & Browse Transactions Action
            StreamBuilder<FinancialSummary>(
              stream: summaryStream,
              builder: (context, snapshot) {
                final income = snapshot.data?.totalIncome ?? 0.0;
                final expense = snapshot.data?.totalExpense ?? 0.0;
                final savings = snapshot.data?.netSavings ?? 0.0;
                final savingsRate = income > 0 ? ((income - expense) / income) * 100 : 0.0;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
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
                      if (income > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.savings_rounded, size: 14, color: AppColors.primary),
                                  SizedBox(width: 6),
                                  Text(
                                    'Savings Rate',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                                  ),
                                ],
                              ),
                              Text(
                                '${savingsRate.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: savingsRate >= 20 ? AppColors.income : (savingsRate >= 0 ? AppColors.primary : AppColors.expense),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _showPeriodTransactionsSheet(context, startDate, endDate, rangeLabel),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 14, color: AppColors.primary),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Browse all transactions in this period',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.primary),
                            ],
                          ),

                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Segmented Analytics Sub-Tab Navigation
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Row(
                children: [
                  _buildSubTabButton(0, 'Overview & Trends', Icons.insights_rounded),
                  _buildSubTabButton(1, 'Categories & 50/30/20', Icons.donut_large_rounded),
                  _buildSubTabButton(2, 'Pacing & Payees', Icons.trending_up_rounded),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── TAB 0: OVERVIEW & CASH FLOW TRENDS ───
            if (_currentTabIndex == 0) ...[
              StreamBuilder<List<CashFlowMonthlyPoint>>(
                stream: cashFlowStream,
                builder: (context, snapshot) {
                  return CashFlowBarChart(points: snapshot.data ?? []);
                },
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<DayOfWeekSpending>>(
                stream: dayOfWeekStream,
                builder: (context, snapshot) {
                  return DayOfWeekHeatmap(dayList: snapshot.data ?? []);
                },
              ),

            ],

            // ─── TAB 1: CATEGORIES & 50/30/20 ANALYZER ───
            if (_currentTabIndex == 1) ...[
              // Donut Chart
              StreamBuilder<List<CategorySpending>>(
                stream: categorySpendingStream,
                builder: (context, snapshot) {
                  final categories = snapshot.data ?? [];

                  if (categories.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.pie_chart_outline_rounded, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No spending recorded for this timeframe', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 220,
                          child: PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback: (event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection == null) {
                                      _touchedSectionIndex = -1;
                                      return;
                                    }
                                    _touchedSectionIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                  });
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 3,
                              centerSpaceRadius: 55,
                              sections: List.generate(categories.length, (i) {
                                final isTouched = i == _touchedSectionIndex;
                                final fontSize = isTouched ? 16.0 : 12.0;
                                final radius = isTouched ? 65.0 : 50.0;
                                final item = categories[i];

                                return PieChartSectionData(
                                  color: Color(item.category.color),
                                  value: item.totalAmount,
                                  title: '${item.percentage.toStringAsFixed(0)}%',
                                  radius: radius,
                                  titleStyle: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        if (_touchedSectionIndex >= 0 && _touchedSectionIndex < categories.length) ...[
                          const SizedBox(height: 12),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showCategoryTransactionsSheet(context, categories[_touchedSectionIndex].category, startDate, endDate),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Color(categories[_touchedSectionIndex].category.color).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Color(categories[_touchedSectionIndex].category.color).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    IconHelper.getCategoryIcon(categories[_touchedSectionIndex].category.icon),
                                    size: 16,
                                    color: Color(categories[_touchedSectionIndex].category.color),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${categories[_touchedSectionIndex].category.name}: ${CurrencyFormatter.format(categories[_touchedSectionIndex].totalAmount)} (${categories[_touchedSectionIndex].percentage.toStringAsFixed(1)}%)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(categories[_touchedSectionIndex].category.color),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_right_rounded, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // 50/30/20 Macro Budget Health Card
              StreamBuilder<Macro503020Summary>(
                stream: macro503020Stream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return Macro503020Card(summary: snapshot.data!);
                },
              ),

              const SizedBox(height: 16),

              // Category Trends List with MoM delta & tap to inspect
              StreamBuilder<List<CategoryTrendItem>>(
                stream: categoryTrendsStream,
                builder: (context, snapshot) {
                  final trends = snapshot.data ?? [];
                  final totalSpend = trends.fold<double>(0.0, (s, t) => s + t.currentAmount);
                  return CategoryTrendList(
                    trends: trends,
                    totalSpending: totalSpend,
                    onCategoryTap: (cat) => _showCategoryTransactionsSheet(context, cat, startDate, endDate),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Tag Spending Matrix
              StreamBuilder<List<TagSpendingItem>>(
                stream: tagsStream,
                builder: (context, snapshot) {
                  return TagMatrixWidget(tags: snapshot.data ?? []);
                },
              ),
            ],

            // ─── TAB 2: PACING, VELOCITY & TOP PAYEES ───
            if (_currentTabIndex == 2) ...[
              StreamBuilder<SpendingVelocityData>(
                stream: velocityStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return SpendingVelocityChart(velocity: snapshot.data!);
                },
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<TopMerchantItem>>(
                stream: merchantsStream,
                builder: (context, snapshot) {
                  return TopMerchantsCard(merchants: snapshot.data ?? []);
                },
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabButton(int index, String title, IconData icon) {
    final isSelected = _currentTabIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
