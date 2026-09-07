import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/services/app_review_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/sonner_toast.dart';
import '../../../recycle_bin/data/recycle_bin_repository.dart';
import '../../data/goal_repository.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  bool _showCompleted = false;

  void _showAddGoalDialog({Goal? editGoal}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddEditGoalSheet(editGoal: editGoal),
    );
  }

  void _showDepositWithdrawDialog(Goal goal, {required bool isDeposit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DepositWithdrawSheet(goal: goal, isDeposit: isDeposit),
    );
  }

  void _showGoalDetailsSheet(Goal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GoalDetailsSheet(
        initialGoal: goal,
        onDeposit: () {
          Navigator.pop(context);
          _showDepositWithdrawDialog(goal, isDeposit: true);
        },
        onWithdraw: () {
          Navigator.pop(context);
          _showDepositWithdrawDialog(goal, isDeposit: false);
        },
        onEdit: () {
          Navigator.pop(context);
          _showAddGoalDialog(editGoal: goal);
        },
      ),
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
    ref.watch(currencyProvider);
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
                          const Flexible(
                            child: Text(
                              'Total Target Milestone',
                              style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(summary.overallProgress * 100).toStringAsFixed(1)}% Saved',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            CurrencyFormatter.format(summary.totalSaved),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
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

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _showGoalDetailsSheet(goal),
                        child: Container(
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
                                            Expanded(
                                              child: Text(
                                                goal.name,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                                overflow: TextOverflow.ellipsis,
                                              ),
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
                                      if (action == 'details') {
                                        _showGoalDetailsSheet(goal);
                                      } else if (action == 'edit') {
                                        _showAddGoalDialog(editGoal: goal);
                                      } else if (action == 'delete') {
                                        final recycleRepo = ref.read(recycleBinRepositoryProvider);
                                        final recycleId = await recycleRepo.moveGoalToRecycleBin(goal.id);

                                        Sonner.success(
                                          'Moved "${goal.name}" to Recycle Bin',
                                          description: 'Tap undo to restore or find it in Settings > Recycle Bin',
                                          undoLabel: 'UNDO',
                                          onUndo: () async {
                                            if (recycleId.isNotEmpty) {
                                              await recycleRepo.restoreItem(recycleId);
                                              Sonner.success('Restored "${goal.name}"');
                                            }
                                          },
                                        );
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'details',
                                        child: Row(
                                          children: [
                                            Icon(Icons.history_rounded, size: 16),
                                            SizedBox(width: 8),
                                            Text('History & Details'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 16),
                                            SizedBox(width: 8),
                                            Text('Edit Goal'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete Goal', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${CurrencyFormatter.format(goal.currentAmount)} of ${CurrencyFormatter.format(goal.targetAmount)}',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _showGoalDetailsSheet(goal),
                                    icon: const Icon(Icons.history_rounded, size: 16),
                                    label: const Text('History', style: TextStyle(fontSize: 12)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _showDepositWithdrawDialog(goal, isDeposit: false),
                                        icon: const Icon(Icons.remove_rounded, size: 15),
                                        label: const Text('Withdraw', style: TextStyle(fontSize: 11)),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () => _showDepositWithdrawDialog(goal, isDeposit: true),
                                        icon: const Icon(Icons.add_rounded, size: 15),
                                        label: const Text('Deposit', style: TextStyle(fontSize: 11)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: goalColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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

class _GoalDetailsSheet extends ConsumerWidget {
  final Goal initialGoal;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;
  final VoidCallback onEdit;

  const _GoalDetailsSheet({
    required this.initialGoal,
    required this.onDeposit,
    required this.onWithdraw,
    required this.onEdit,
  });

  IconData _resolveIcon(String iconName) {
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
      default:
        return Icons.savings_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goalsList = ref.watch(goalsStreamProvider(null)).valueOrNull ?? [];
    final goal = goalsList.firstWhere((g) => g.id == initialGoal.id, orElse: () => initialGoal);
    final goalColor = Color(goal.colorValue);
    final progress = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final remaining = (goal.targetAmount - goal.currentAmount).clamp(0.0, double.infinity);
    final transactionsAsync = ref.watch(goalTransactionsStreamProvider(goal.id));

    String? monthlySavingEstimate;
    if (goal.targetDate != null && !goal.isCompleted && remaining > 0) {
      final now = DateTime.now();
      final daysLeft = goal.targetDate!.difference(now).inDays;
      if (daysLeft > 0) {
        final monthsLeft = (daysLeft / 30.44).clamp(1.0, 120.0);
        final monthlyNeed = remaining / monthsLeft;
        monthlySavingEstimate = '${CurrencyFormatter.format(monthlyNeed)}/mo needed ($daysLeft days left)';
      }
    }

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: goalColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_resolveIcon(goal.iconName), color: goalColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            if (goal.isCompleted) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 12, color: Colors.green),
                                    SizedBox(width: 4),
                                    Text('Goal Achieved! 🎉', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green)),
                                  ],
                                ),
                              ),
                            ] else if (goal.targetDate != null) ...[
                              Text(
                                'Target: ${DateFormat.yMMMd().format(goal.targetDate!)}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ] else ...[
                              const Text('Active Milestone', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                    tooltip: 'Edit goal',
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Financial Progress Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Current Saved', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.format(goal.currentAmount),
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: goalColor),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Target Goal', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.format(goal.targetAmount),
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: Colors.grey.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(goalColor),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(progress * 100).toStringAsFixed(1)}% completed',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                              ),
                              Text(
                                remaining > 0 ? '${CurrencyFormatter.format(remaining)} remaining' : 'Fully Funded',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: remaining > 0 ? Colors.grey : Colors.green,
                                ),
                              ),
                            ],
                          ),
                          if (monthlySavingEstimate != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: goalColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                monthlySavingEstimate,
                                style: TextStyle(fontSize: 11, color: goalColor, fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Quick Action Buttons (Deposit / Withdraw)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onWithdraw,
                            icon: const Icon(Icons.remove_rounded, size: 18),
                            label: const Text('Withdraw', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.expense,
                              side: const BorderSide(color: AppColors.expense),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onDeposit,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Deposit', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: goalColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Notes / Motivation
                    if (goal.notes != null && goal.notes!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5) : AppColors.lightSurfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline_rounded, size: 18, color: AppColors.warning),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                goal.notes!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Goal Activity Timeline Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Savings Activity History',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        TextButton.icon(
                          onPressed: onDeposit,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Deposit', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    transactionsAsync.when(
                      data: (transactions) {
                        if (transactions.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 36, color: Colors.grey),
                                SizedBox(height: 8),
                                Text(
                                  'No transactions recorded yet',
                                  style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Every deposit or withdrawal made for this goal will be logged here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: transactions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final tx = transactions[index];
                            final isDep = tx.type == 'deposit';

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: (isDep ? AppColors.income : AppColors.expense).withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isDep ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                      color: isDep ? AppColors.income : AppColors.expense,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              '${isDep ? "+" : "-"} ${CurrencyFormatter.format(tx.amount)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isDep ? AppColors.income : AppColors.expense,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: (isDep ? AppColors.income : AppColors.expense).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isDep ? 'Deposit' : 'Withdrawal',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDep ? AppColors.income : AppColors.expense,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            tx.notes!,
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(tx.date),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expense),
                                    tooltip: 'Delete transaction',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Transaction?'),
                                          content: Text(
                                            'Remove ${isDep ? "deposit" : "withdrawal"} of ${CurrencyFormatter.format(tx.amount)}? '
                                            'This will adjust the goal saved balance accordingly.',
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await ref.read(goalRepositoryProvider).deleteGoalTransaction(tx.id);
                                        Sonner.success('Goal transaction removed');
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
                      error: (err, _) => Text('Error loading history: $err'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEditGoalSheet extends ConsumerStatefulWidget {
  final Goal? editGoal;
  const _AddEditGoalSheet({this.editGoal});

  @override
  ConsumerState<_AddEditGoalSheet> createState() => _AddEditGoalSheetState();
}

class _AddEditGoalSheetState extends ConsumerState<_AddEditGoalSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetAmountController;
  late final TextEditingController _currentAmountController;
  late final TextEditingController _notesController;
  DateTime? _selectedDate;
  late int _selectedColor;
  late String _selectedIcon;

  static const _availableColors = [
    0xFF10B981, // Emerald
    0xFF3B82F6, // Blue
    0xFF8B5CF6, // Purple
    0xFFF59E0B, // Amber
    0xFFEC4899, // Pink
    0xFFEF4444, // Red
    0xFF06B6D4, // Cyan
    0xFF6366F1, // Indigo
  ];

  static const _availableIcons = [
    {'name': 'savings', 'icon': Icons.savings_rounded, 'label': 'Savings'},
    {'name': 'flight', 'icon': Icons.flight_takeoff_rounded, 'label': 'Travel'},
    {'name': 'laptop', 'icon': Icons.laptop_mac_rounded, 'label': 'Tech'},
    {'name': 'home', 'icon': Icons.home_rounded, 'label': 'House'},
    {'name': 'directions_car', 'icon': Icons.directions_car_rounded, 'label': 'Vehicle'},
    {'name': 'school', 'icon': Icons.school_rounded, 'label': 'Education'},
    {'name': 'favorite', 'icon': Icons.favorite_rounded, 'label': 'Health'},
    {'name': 'card_giftcard', 'icon': Icons.card_giftcard_rounded, 'label': 'Gift'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editGoal?.name ?? '');
    _targetAmountController = TextEditingController(
      text: widget.editGoal != null ? widget.editGoal!.targetAmount.toStringAsFixed(2) : '',
    );
    _currentAmountController = TextEditingController(
      text: widget.editGoal != null ? widget.editGoal!.currentAmount.toStringAsFixed(2) : '',
    );
    _notesController = TextEditingController(text: widget.editGoal?.notes ?? '');
    _selectedDate = widget.editGoal?.targetDate;
    _selectedColor = widget.editGoal?.colorValue ?? 0xFF10B981;
    _selectedIcon = widget.editGoal?.iconName ?? 'savings';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.editGoal != null;

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Savings Goal' : 'New Savings Goal',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Goal Title (e.g. Vacation, Laptop)',
                        prefixIcon: const Icon(Icons.flag_rounded, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _targetAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Target Amount',
                        prefixText: '${CurrencyFormatter.activeCurrencySymbol} ',
                        prefixIcon: const Icon(Icons.track_changes_rounded, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _currentAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Current Saved Amount',
                        prefixText: '${CurrencyFormatter.activeCurrencySymbol} ',
                        prefixIcon: const Icon(Icons.account_balance_wallet_rounded, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Target Date Picker
                    Material(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 90)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Target Date (Optional)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text(
                                    _selectedDate == null ? 'Not set (tap to pick)' : DateFormat.yMMMd().format(_selectedDate!),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedDate == null ? Colors.grey : null,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              if (_selectedDate != null)
                                GestureDetector(
                                  onTap: () => setState(() => _selectedDate = null),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                                  ),
                                ),
                              const Text('Set Date', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Color Picker
                    const Text('Goal Color', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _availableColors.map((c) {
                        final isSelected = _selectedColor == c;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = c),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Color(c).withValues(alpha: 0.6),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Icon Picker
                    const Text('Goal Category / Icon', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableIcons.map((item) {
                        final isSelected = _selectedIcon == item['name'];
                        return ChoiceChip(
                          avatar: Icon(item['icon'] as IconData, size: 16, color: isSelected ? Colors.white : AppColors.primary),
                          label: Text(item['label'] as String),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          onSelected: (_) => setState(() => _selectedIcon = item['name'] as String),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes / Motivation (Optional)',
                        hintText: 'e.g. Saving for Tokyo trip!',
                        prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = _nameController.text.trim();
                          final target = double.tryParse(_targetAmountController.text.trim()) ?? 0.0;
                          final current = double.tryParse(_currentAmountController.text.trim()) ?? 0.0;
                          if (name.isEmpty || target <= 0) return;

                          final repo = ref.read(goalRepositoryProvider);
                          if (widget.editGoal == null) {
                            const uuid = Uuid();
                            await repo.createGoal(
                              GoalsCompanion.insert(
                                id: uuid.v4(),
                                name: name,
                                targetAmount: target,
                                currentAmount: drift.Value(current),
                                targetDate: drift.Value(_selectedDate),
                                colorValue: drift.Value(_selectedColor),
                                iconName: drift.Value(_selectedIcon),
                                notes: drift.Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
                              ),
                            );
                          } else {
                            final isCompleted = current >= target;
                            await repo.updateGoal(
                              GoalsCompanion(
                                id: drift.Value(widget.editGoal!.id),
                                name: drift.Value(name),
                                targetAmount: drift.Value(target),
                                currentAmount: drift.Value(current),
                                targetDate: drift.Value(_selectedDate),
                                colorValue: drift.Value(_selectedColor),
                                iconName: drift.Value(_selectedIcon),
                                notes: drift.Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
                                isCompleted: drift.Value(isCompleted),
                                createdAt: drift.Value(widget.editGoal!.createdAt),
                              ),
                            );
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            Sonner.success(
                              widget.editGoal == null ? 'Goal "$name" created!' : 'Goal "$name" updated!',
                              description: CurrencyFormatter.format(target),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(_selectedColor),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(isEditing ? 'Save Changes' : 'Create Goal', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepositWithdrawSheet extends ConsumerStatefulWidget {
  final Goal goal;
  final bool isDeposit;
  const _DepositWithdrawSheet({required this.goal, required this.isDeposit});

  @override
  ConsumerState<_DepositWithdrawSheet> createState() => _DepositWithdrawSheetState();
}

class _DepositWithdrawSheetState extends ConsumerState<_DepositWithdrawSheet> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _transactionDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDeposit = widget.isDeposit;
    final remaining = widget.goal.targetAmount - widget.goal.currentAmount;

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDeposit ? AppColors.income : AppColors.expense).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDeposit ? Icons.add_rounded : Icons.remove_rounded,
                      color: isDeposit ? AppColors.income : AppColors.expense,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDeposit ? 'Deposit to Goal' : 'Withdraw from Goal',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        Text(widget.goal.name, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Current Saved', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(CurrencyFormatter.format(widget.goal.currentAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Target Milestone', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(CurrencyFormatter.format(widget.goal.targetAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Amount input
                    TextField(
                      controller: _amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: isDeposit ? 'Deposit Amount' : 'Withdrawal Amount',
                        prefixText: '${CurrencyFormatter.activeCurrencySymbol} ',
                        prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick preset chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: isDeposit
                            ? [
                                ActionChip(
                                  label: const Text('+100'),
                                  onPressed: () => setState(() => _amountController.text = '100'),
                                ),
                                const SizedBox(width: 8),
                                ActionChip(
                                  label: const Text('+500'),
                                  onPressed: () => setState(() => _amountController.text = '500'),
                                ),
                                const SizedBox(width: 8),
                                ActionChip(
                                  label: const Text('+1,000'),
                                  onPressed: () => setState(() => _amountController.text = '1000'),
                                ),
                                if (remaining > 0) ...[
                                  const SizedBox(width: 8),
                                  ActionChip(
                                    label: const Text('Remaining Target'),
                                    onPressed: () => setState(() => _amountController.text = remaining.toStringAsFixed(2)),
                                  ),
                                ],
                              ]
                            : [
                                ActionChip(
                                  label: const Text('25%'),
                                  onPressed: () => setState(() => _amountController.text = (widget.goal.currentAmount * 0.25).toStringAsFixed(2)),
                                ),
                                const SizedBox(width: 8),
                                ActionChip(
                                  label: const Text('50%'),
                                  onPressed: () => setState(() => _amountController.text = (widget.goal.currentAmount * 0.5).toStringAsFixed(2)),
                                ),
                                const SizedBox(width: 8),
                                ActionChip(
                                  label: const Text('All Saved'),
                                  onPressed: () => setState(() => _amountController.text = widget.goal.currentAmount.toStringAsFixed(2)),
                                ),
                              ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date picker
                    Material(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _transactionDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() => _transactionDate = picked);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Date', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(_transactionDate),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Text('Change', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Notes / Reason input
                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes / Reason (Optional)',
                        hintText: isDeposit ? 'e.g. Salary savings, gift, bonus' : 'e.g. Purchased item, emergency',
                        prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Full-width action button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
                          if (amount <= 0) return;

                          final note = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

                          if (isDeposit) {
                            await ref.read(goalRepositoryProvider).depositToGoal(
                                  widget.goal.id,
                                  amount,
                                  date: _transactionDate,
                                  notes: note,
                                );
                            if (widget.goal.currentAmount + amount >= widget.goal.targetAmount) {
                              ref.read(appReviewServiceProvider).recordGoalCompleted();
                            }
                          } else {
                            await ref.read(goalRepositoryProvider).withdrawFromGoal(
                                  widget.goal.id,
                                  amount,
                                  date: _transactionDate,
                                  notes: note,
                                );
                          }

                          if (context.mounted) {
                            Navigator.pop(context);
                            Sonner.success(
                              isDeposit ? 'Deposited to "${widget.goal.name}"' : 'Withdrawn from "${widget.goal.name}"',
                              description: CurrencyFormatter.format(amount),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDeposit ? AppColors.income : AppColors.expense,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          isDeposit ? 'Confirm Deposit' : 'Confirm Withdrawal',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
