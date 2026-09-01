import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../categories/data/category_repository.dart';
import '../../../transactions/data/transaction_repository.dart';
import '../../data/budget_repository.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
  }

  void _resetToCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _selectedMonth = DateTime(now.year, now.month, 1);
    });
  }

  void _showAddBudgetDialog(BuildContext context) {
    final categoriesAsync = ref.read(categoriesStreamProvider('expense'));
    final amountController = TextEditingController();
    String? selectedCatId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create Monthly Budget', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  categoriesAsync.when(
                    data: (categories) {
                      return DropdownButtonFormField<String>(
                        initialValue: selectedCatId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: categories.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Row(
                              children: [
                                Icon(IconHelper.getIcon(c.icon), size: 18, color: Color(c.color)),
                                const SizedBox(width: 8),
                                Text(c.name),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => selectedCatId = val),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, _) => const Text('Error loading categories'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Monthly Limit Amount',
                      prefixText: '${CurrencyFormatter.activeCurrencySymbol} ',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (selectedCatId == null || amount <= 0) return;

                    const uuid = Uuid();
                    await ref.read(budgetRepositoryProvider).createBudget(
                          BudgetsCompanion.insert(
                            id: uuid.v4(),
                            categoryId: selectedCatId!,
                            amountLimit: amount,
                          ),
                        );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✓ Budget created (${CurrencyFormatter.format(amount)})')),
                      );
                    }
                  },
                  child: const Text('Save Budget'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCategoryTransactionsSheet(BuildContext context, BudgetWithProgress item) {
    final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
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
                          color: Color(item.category.color).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          IconHelper.getIcon(item.category.icon),
                          color: Color(item.category.color),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.category.name} Expenses',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              DateFormat('MMMM yyyy').format(_selectedMonth),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.format(item.currentSpent),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.expense,
                            ),
                          ),
                          Text(
                            'Limit: ${CurrencyFormatter.format(item.budget.amountLimit)}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: StreamBuilder<List<TransactionWithDetails>>(
                      stream: ref.watch(transactionRepositoryProvider).watchTransactionsWithDetails(
                            startDate: startOfMonth,
                            endDate: endOfMonth,
                            categoryId: item.category.id,
                            type: 'expense',
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
                                  'No ${item.category.name} expenses in ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollController,
                          itemCount: txs.length,
                          separatorBuilder: (context, index) => const Divider(height: 12),
                          itemBuilder: (context, index) {
                            final txWithDetails = txs[index];
                            final tx = txWithDetails.transaction;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text(
                                '${DateFormat('MMM d, yyyy').format(tx.date)}${tx.note != null && tx.note!.isNotEmpty ? ' • ${tx.note}' : ''}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              trailing: Text(
                                '-${CurrencyFormatter.format(tx.amount)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.expense,
                                ),
                              ),
                            );
                          },
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

  @override
  Widget build(BuildContext context) {
    ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final budgetsAsync = ref.watch(monthBudgetsProvider(_selectedMonth));
    final now = DateTime.now();
    final isCurrentMonth = _selectedMonth.year == now.year && _selectedMonth.month == now.month;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddBudgetDialog(context),
            tooltip: 'Create Budget',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Switcher Header
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
                    onPressed: _previousMonth,
                    tooltip: 'Previous Month',
                  ),
                  GestureDetector(
                    onTap: _resetToCurrentMonth,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('MMMM yyyy').format(_selectedMonth),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (!isCurrentMonth) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Today', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    onPressed: _nextMonth,
                    tooltip: 'Next Month',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            budgetsAsync.when(
              data: (budgets) {
                if (budgets.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    margin: const EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.track_changes_rounded, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'No budgets configured',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Set spending caps for categories like Groceries, Dining, or Shopping.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showAddBudgetDialog(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create Your First Budget'),
                        ),
                      ],
                    ),
                  );
                }

                // Calculate Totals for the Month
                final totalLimit = budgets.fold<double>(0.0, (s, b) => s + b.budget.amountLimit);
                final totalSpent = budgets.fold<double>(0.0, (s, b) => s + b.currentSpent);
                final overallPercentage = totalLimit > 0 ? (totalSpent / totalLimit) * 100 : 0.0;
                final overallRemaining = totalLimit - totalSpent;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total Monthly Budget Overview Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Budgeted', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                '${overallPercentage.toStringAsFixed(0)}% used',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: overallRemaining >= 0 ? AppColors.primary : AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${CurrencyFormatter.format(totalSpent)} / ${CurrencyFormatter.format(totalLimit)}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                overallRemaining >= 0
                                    ? '${CurrencyFormatter.format(overallRemaining)} left'
                                    : 'Over by ${CurrencyFormatter.format(-overallRemaining)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: overallRemaining >= 0 ? AppColors.income : AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (overallPercentage / 100).clamp(0.0, 1.0),
                              backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                              valueColor: AlwaysStoppedAnimation(
                                overallRemaining < 0
                                    ? AppColors.expense
                                    : (overallPercentage >= 80 ? AppColors.warning : AppColors.primary),
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Section Heading
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Category Spending Budgets (${budgets.length})',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Tap to view expenses', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),


                    const SizedBox(height: 10),

                    // Individual Category Budget Cards
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: budgets.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = budgets[index];
                        final budget = item.budget;
                        final cat = item.category;

                        Color statusColor = AppColors.income;
                        if (item.isOverBudget) {
                          statusColor = AppColors.expense;
                        } else if (item.isNearLimit) {
                          statusColor = AppColors.warning;
                        }

                        return Dismissible(
                          key: Key(budget.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            alignment: Alignment.centerRight,
                            decoration: BoxDecoration(
                              color: AppColors.expense,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          onDismissed: (_) async {
                            final repo = ref.read(budgetRepositoryProvider);
                            await repo.deleteBudget(budget.id);

                            if (context.mounted) {
                              final messenger = ScaffoldMessenger.of(context);
                              messenger.clearSnackBars();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Deleted ${cat.name} budget'),
                                  duration: const Duration(seconds: 5),
                                  action: SnackBarAction(
                                    label: 'UNDO',
                                    textColor: AppColors.income,
                                    onPressed: () async {
                                      await repo.restoreBudget(budget);
                                      messenger.clearSnackBars();
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('✓ Restored ${cat.name} budget'),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }
                          },

                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _showCategoryTransactionsSheet(context, item),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: item.isOverBudget
                                      ? AppColors.expense.withValues(alpha: 0.5)
                                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                  width: item.isOverBudget ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Color(cat.color).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(IconHelper.getIcon(cat.icon), color: Color(cat.color), size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                            const SizedBox(height: 2),
                                            Text(
                                              item.isOverBudget
                                                  ? 'Over budget by ${CurrencyFormatter.format(item.currentSpent - budget.amountLimit)}'
                                                  : '${CurrencyFormatter.format(item.remaining)} remaining',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: statusColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${CurrencyFormatter.format(item.currentSpent)} / ${CurrencyFormatter.format(budget.amountLimit)}',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${item.percentage.toStringAsFixed(0)}% used',
                                                style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: (item.percentage / 100).clamp(0.0, 1.0),
                                      backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                      valueColor: AlwaysStoppedAnimation(statusColor),
                                      minHeight: 6,
                                    ),
                                  ),
                                  if (item.transactionCount > 0) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '${item.transactionCount} expense${item.transactionCount > 1 ? "s" : ""} recorded this month',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error: $err'),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
