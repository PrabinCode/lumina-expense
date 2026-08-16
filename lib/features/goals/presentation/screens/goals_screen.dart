import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/goal_repository.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  bool _showCompleted = false;

  void _showAddGoalDialog({Goal? editGoal}) {
    final nameController = TextEditingController(text: editGoal?.name ?? '');
    final targetAmountController = TextEditingController(
      text: editGoal != null ? editGoal.targetAmount.toStringAsFixed(2) : '',
    );
    final currentAmountController = TextEditingController(
      text: editGoal != null ? editGoal.currentAmount.toStringAsFixed(2) : '',
    );
    final notesController = TextEditingController(text: editGoal?.notes ?? '');
    DateTime? selectedDate = editGoal?.targetDate;
    int selectedColor = editGoal?.colorValue ?? 0xFF10B981;
    String selectedIcon = editGoal?.iconName ?? 'savings';

    final availableColors = [
      0xFF10B981, // Emerald
      0xFF3B82F6, // Blue
      0xFF8B5CF6, // Purple
      0xFFF59E0B, // Amber
      0xFFEC4899, // Pink
      0xFF06B6D4, // Cyan
      0xFFF97316, // Orange
      0xFF6366F1, // Indigo
    ];

    final availableIcons = [
      {'name': 'savings', 'icon': Icons.savings_rounded, 'label': 'Savings'},
      {'name': 'flight', 'icon': Icons.flight_takeoff_rounded, 'label': 'Travel'},
      {'name': 'laptop', 'icon': Icons.laptop_mac_rounded, 'label': 'Tech'},
      {'name': 'home', 'icon': Icons.home_rounded, 'label': 'Home'},
      {'name': 'directions_car', 'icon': Icons.directions_car_rounded, 'label': 'Car'},
      {'name': 'school', 'icon': Icons.school_rounded, 'label': 'Education'},
      {'name': 'favorite', 'icon': Icons.favorite_rounded, 'label': 'Emergency'},
      {'name': 'card_giftcard', 'icon': Icons.card_giftcard_rounded, 'label': 'Gift'},
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                editGoal == null ? 'New Savings Goal' : 'Edit Savings Goal',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Goal Title (e.g. Vacation, Laptop)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: targetAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Target Amount',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: currentAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Current Saved Amount',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Target Date Picker
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      leading: const Icon(Icons.event_rounded, color: AppColors.primary),
                      title: Text(
                        selectedDate == null
                            ? 'Set Target Date (Optional)'
                            : 'Target: ${DateFormat.yMMMd().format(selectedDate!)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: selectedDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setDialogState(() => selectedDate = null),
                            )
                          : null,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 90)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Select Icon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableIcons.map((item) {
                        final isSelected = selectedIcon == item['name'];
                        return InkWell(
                          onTap: () => setDialogState(() => selectedIcon = item['name'] as String),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Color(selectedColor).withValues(alpha: 0.2)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Color(selectedColor) : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(item['icon'] as IconData, size: 20, color: Color(selectedColor)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Color Accent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableColors.map((colorVal) {
                        final isSelected = selectedColor == colorVal;
                        return InkWell(
                          onTap: () => setDialogState(() => selectedColor = colorVal),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color(colorVal),
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final target = double.tryParse(targetAmountController.text.trim()) ?? 0.0;
                    final current = double.tryParse(currentAmountController.text.trim()) ?? 0.0;
                    if (name.isEmpty || target <= 0) return;

                    final isCompleted = current >= target;

                    if (editGoal == null) {
                      const uuid = Uuid();
                      await ref.read(goalRepositoryProvider).createGoal(
                            GoalsCompanion.insert(
                              id: uuid.v4(),
                              name: name,
                              targetAmount: target,
                              currentAmount: drift.Value(current),
                              targetDate: drift.Value(selectedDate),
                              iconName: drift.Value(selectedIcon),
                              colorValue: drift.Value(selectedColor),
                              notes: drift.Value(notesController.text.trim().isEmpty ? null : notesController.text.trim()),
                              isCompleted: drift.Value(isCompleted),
                            ),
                          );
                    } else {
                      await ref.read(goalRepositoryProvider).updateGoal(
                            GoalsCompanion(
                              id: drift.Value(editGoal.id),
                              name: drift.Value(name),
                              targetAmount: drift.Value(target),
                              currentAmount: drift.Value(current),
                              targetDate: drift.Value(selectedDate),
                              iconName: drift.Value(selectedIcon),
                              colorValue: drift.Value(selectedColor),
                              notes: drift.Value(notesController.text.trim().isEmpty ? null : notesController.text.trim()),
                              isCompleted: drift.Value(isCompleted),
                              createdAt: drift.Value(editGoal.createdAt),
                            ),
                          );
                    }

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save Goal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDepositWithdrawDialog(Goal goal, {required bool isDeposit}) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isDeposit ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                color: isDeposit ? AppColors.income : AppColors.expense,
              ),
              const SizedBox(width: 8),
              Text(isDeposit ? 'Deposit to ${goal.name}' : 'Withdraw from ${goal.name}', style: const TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current Saved: ${CurrencyFormatter.format(goal.currentAmount)} / ${CurrencyFormatter.format(goal.targetAmount)}'),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isDeposit ? 'Deposit Amount' : 'Withdrawal Amount',
                  prefixText: '\$ ',
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
                if (amount <= 0) return;

                if (isDeposit) {
                  await ref.read(goalRepositoryProvider).depositToGoal(goal.id, amount);
                } else {
                  await ref.read(goalRepositoryProvider).withdrawFromGoal(goal.id, amount);
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: Text(isDeposit ? 'Confirm Deposit' : 'Confirm Withdrawal'),
            ),
          ],
        );
      },
    );
  }

  IconData _getGoalIcon(String iconName) {
    switch (iconName) {
      case 'flight':
        return Icons.flight_takeoff_rounded;
      case 'laptop':
        return Icons.laptop_mac_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      case 'savings':
      default:
        return Icons.savings_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summaryAsync = ref.watch(goalsSummaryStreamProvider);
    final goalsAsync = ref.watch(goalsStreamProvider(_showCompleted ? null : false));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals & Sinking Funds'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Goal',
            onPressed: () => _showAddGoalDialog(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Overview Summary Card
            summaryAsync.when(
              data: (summary) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [const Color(0xFFE0F2FE), const Color(0xFFF0FDF4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Target Milestone', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                          Text(
                            '${(summary.overallProgress * 100).toStringAsFixed(1)}% Saved',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            CurrencyFormatter.format(summary.totalSaved),
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primary),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '/ ${CurrencyFormatter.format(summary.totalTarget)}',
                            style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: summary.overallProgress,
                          minHeight: 8,
                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${summary.totalGoals} Goals Active', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          Text('${summary.completedGoals} Completed ✓', style: const TextStyle(fontSize: 11, color: AppColors.income, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Tab Filter Bar
            Row(
              children: [
                ChoiceChip(
                  label: const Text('In Progress'),
                  selected: !_showCompleted,
                  onSelected: (sel) => setState(() => _showCompleted = !sel),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('All Goals'),
                  selected: _showCompleted,
                  onSelected: (sel) => setState(() => _showCompleted = sel),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Goals List
            goalsAsync.when(
              data: (goals) {
                if (goals.isEmpty) {
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
                        const Icon(Icons.savings_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('No savings goals yet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 6),
                        const Text('Create target milestones to track and achieve your future dreams.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showAddGoalDialog(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create First Goal'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: goals.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final goal = goals[index];
                    final progress = goal.targetAmount > 0
                        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
                        : 0.0;
                    final remaining = (goal.targetAmount - goal.currentAmount).clamp(0.0, double.infinity);
                    final goalColor = Color(goal.colorValue);

                    // Calculation for monthly required savings
                    String? monthlySavingEstimate;
                    if (goal.targetDate != null && !goal.isCompleted && remaining > 0) {
                      final now = DateTime.now();
                      final daysLeft = goal.targetDate!.difference(now).inDays;
                      if (daysLeft > 0) {
                        final monthsLeft = (daysLeft / 30.44).clamp(1.0, 120.0);
                        final monthlyNeed = remaining / monthsLeft;
                        monthlySavingEstimate = '${CurrencyFormatter.format(monthlyNeed)}/mo needed (${daysLeft}d left)';
                      }
                    }

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: goal.isCompleted
                              ? AppColors.income.withValues(alpha: 0.5)
                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
                                  color: goalColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(_getGoalIcon(goal.iconName), color: goalColor, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          goal.name,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                        ),
                                        if (goal.isCompleted) ...[
                                          const SizedBox(width: 6),
                                          const Icon(Icons.check_circle_rounded, color: AppColors.income, size: 16),
                                        ],
                                      ],
                                    ),
                                    if (monthlySavingEstimate != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        monthlySavingEstimate,
                                        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                                      ),
                                    ] else if (goal.targetDate != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Target: ${DateFormat.yMMMd().format(goal.targetDate!)}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (action) async {
                                  if (action == 'edit') {
                                    _showAddGoalDialog(editGoal: goal);
                                  } else if (action == 'delete') {
                                    await ref.read(goalRepositoryProvider).deleteGoal(goal.id);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Edit Goal')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete Goal', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${CurrencyFormatter.format(goal.currentAmount)} of ${CurrencyFormatter.format(goal.targetAmount)}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              Text(
                                '${(progress * 100).toStringAsFixed(1)}%',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: goalColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: isDark ? Colors.white10 : Colors.black12,
                              valueColor: AlwaysStoppedAnimation<Color>(goalColor),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showDepositWithdrawDialog(goal, isDeposit: false),
                                icon: const Icon(Icons.remove_rounded, size: 16),
                                label: const Text('Withdraw', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _showDepositWithdrawDialog(goal, isDeposit: true),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Deposit', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: goalColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error loading goals: $err'),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
