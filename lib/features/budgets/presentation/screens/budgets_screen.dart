import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../categories/data/category_repository.dart';
import '../../data/budget_repository.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  void _showAddBudgetDialog(BuildContext context, WidgetRef ref) {
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
                    decoration: const InputDecoration(
                      labelText: 'Monthly Limit Amount',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
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
                    if (context.mounted) Navigator.pop(context);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(currentMonthBudgetsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddBudgetDialog(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                          onPressed: () => _showAddBudgetDialog(context, ref),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create Your First Budget'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: budgets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                      onDismissed: (_) {
                        ref.read(budgetRepositoryProvider).deleteBudget(budget.id);
                      },
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
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Color(cat.color).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(IconHelper.getIcon(cat.icon), color: Color(cat.color), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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
                                    Text(
                                      '${item.percentage.toStringAsFixed(0)}% used',
                                      style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
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
                          ],
                        ),
                      ),
                    );
                  },
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
