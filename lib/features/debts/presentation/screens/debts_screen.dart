import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/sonner_toast.dart';
import '../../../recycle_bin/data/recycle_bin_repository.dart';
import '../../data/debt_repository.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  bool _showSettled = false;

  void _showAddDebtDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddDebtSheet(),
    );
  }

  void _showSettleDialog(Debt debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecordRepaymentSheet(debt: debt),
    );
  }

  void _showDebtDetailsSheet(Debt debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DebtDetailsSheet(
        initialDebt: debt,
        onAddRepayment: () {
          Navigator.pop(context);
          _showSettleDialog(debt);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summaryAsync = ref.watch(debtSummaryStreamProvider);
    final debtsAsync = ref.watch(debtsStreamProvider(_showSettled ? null : false));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debts & Loans (IOUs)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: _showAddDebtDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Debt Summary Card
            summaryAsync.when(
              data: (summary) {
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
                            const Text('They Owe Me', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(summary.totalLent),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.income),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 24, width: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('I Owe Them', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(summary.totalBorrowed),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.expense),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 24, width: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Net Balance', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(summary.netReceivable),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: summary.netReceivable >= 0 ? AppColors.income : AppColors.expense,
                              ),
                            ),
                          ],
                        ),
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
                    label: const Text('Active Debts'),
                    selected: !_showSettled,
                    onSelected: (sel) => setState(() => _showSettled = !sel),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('All / Settled'),
                    selected: _showSettled,
                    onSelected: (sel) => setState(() => _showSettled = sel),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Debts List
            debtsAsync.when(
              data: (debts) {
                if (debts.isEmpty) {
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
                        Icon(Icons.handshake_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.6)),
                        const SizedBox(height: 12),
                        Text(
                          _showSettled ? 'No settled debts' : 'No active debts or IOUs',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Track money lent to friends or borrowed from others.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _showAddDebtDialog,
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text('Add Debt / Loan', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: debts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final debt = debts[index];
                    final isLent = debt.type == 'lent';
                    final remaining = debt.amount - debt.settledAmount;

                    return Dismissible(
                      key: Key(debt.id),
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
                        final recycleRepo = ref.read(recycleBinRepositoryProvider);
                        final recycleId = await recycleRepo.moveDebtToRecycleBin(debt.id);

                        Sonner.success(
                          'Moved "${debt.personName}" to Recycle Bin',
                          description: 'Tap undo to restore or find it in Settings > Recycle Bin',
                          undoLabel: 'UNDO',
                          onUndo: () async {
                            if (recycleId.isNotEmpty) {
                              await recycleRepo.restoreItem(recycleId);
                              Sonner.success('Restored record for ${debt.personName}');
                            }
                          },
                        );
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showDebtDetailsSheet(debt),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (isLent ? AppColors.income : AppColors.expense).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isLent ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                    color: isLent ? AppColors.income : AppColors.expense,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(debt.personName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text(
                                        isLent ? 'Owes you' : 'You owe',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isLent ? AppColors.income : AppColors.expense,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MMM d, yyyy').format(debt.date),
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      if (debt.notes != null && debt.notes!.isNotEmpty) ...[
                                        Text(
                                          debt.notes!,
                                          style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      CurrencyFormatter.format(remaining),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isLent ? AppColors.income : AppColors.expense,
                                      ),
                                    ),
                                    if (!debt.isSettled) ...[
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () => _showSettleDialog(debt),
                                        child: const Text(
                                          'Repay / Settle',
                                          style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ] else ...[
                                      const Text('Settled ✓', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
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

class _DebtDetailsSheet extends ConsumerWidget {
  final Debt initialDebt;
  final VoidCallback onAddRepayment;

  const _DebtDetailsSheet({
    required this.initialDebt,
    required this.onAddRepayment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debtsList = ref.watch(debtsStreamProvider(null)).valueOrNull ?? [];
    final debt = debtsList.firstWhere((d) => d.id == initialDebt.id, orElse: () => initialDebt);
    final isLent = debt.type == 'lent';
    final remaining = debt.amount - debt.settledAmount;
    final progress = debt.amount > 0 ? (debt.settledAmount / debt.amount).clamp(0.0, 1.0) : 0.0;
    final repaymentsAsync = ref.watch(debtRepaymentsStreamProvider(debt.id));

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

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isLent ? AppColors.income : AppColors.expense).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLent ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      color: isLent ? AppColors.income : AppColors.expense,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.personName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isLent ? AppColors.income : AppColors.expense).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isLent ? 'They Owe You' : 'You Owe Them',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isLent ? AppColors.income : AppColors.expense,
                                ),
                              ),
                            ),
                            if (debt.isSettled) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Settled ✓',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green),
                                ),
                              ),
                            ],
                          ],
                        ),
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
            const SizedBox(height: 16),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Financial Metric Cards
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
                                  const Text('Original Total', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.format(debt.amount),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text('Total Repaid', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.format(debt.settledAmount),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.income),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Remaining', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.format(remaining),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isLent ? AppColors.income : AppColors.expense,
                                    ),
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
                              minHeight: 8,
                              backgroundColor: Colors.grey.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(isLent ? AppColors.income : AppColors.primary),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${(progress * 100).toInt()}% settled', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              if (debt.dueDate != null)
                                Text(
                                  'Due: ${DateFormat('MMM d, yyyy').format(debt.dueDate!)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: debt.dueDate!.isBefore(DateTime.now()) && !debt.isSettled ? AppColors.expense : Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Metadata details (Date borrowed, Notes)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5) : AppColors.lightSurfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                '${isLent ? "Given / Lent on" : "Borrowed on"} ${DateFormat('MMMM d, yyyy').format(debt.date)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          if (debt.notes != null && debt.notes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.notes_rounded, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    debt.notes!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Repayment Activity Timeline
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Repayment History',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        if (!debt.isSettled)
                          TextButton.icon(
                            onPressed: onAddRepayment,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Repayment', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    repaymentsAsync.when(
                      data: (repayments) {
                        if (repayments.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Text(
                                'No repayments recorded yet',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: repayments.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final r = repayments[index];
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
                                      color: AppColors.income.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_rounded, color: AppColors.income, size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          CurrencyFormatter.format(r.amount),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        if (r.notes != null && r.notes!.isNotEmpty)
                                          Text(
                                            r.notes!,
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(r.date),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expense),
                                    tooltip: 'Delete repayment',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Repayment?'),
                                          content: Text('Remove repayment of ${CurrencyFormatter.format(r.amount)}? This will add it back to the remaining balance.'),
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
                                        await ref.read(debtRepositoryProvider).deleteRepayment(r.id);
                                        Sonner.success('Repayment removed');
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

                    const SizedBox(height: 24),

                    // Quick action button
                    if (!debt.isSettled)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: onAddRepayment,
                          icon: const Icon(Icons.payments_outlined, size: 20),
                          label: const Text('Record Repayment / Settle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
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

class _AddDebtSheet extends ConsumerStatefulWidget {
  const _AddDebtSheet();

  @override
  ConsumerState<_AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends ConsumerState<_AddDebtSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _type = 'lent';
  DateTime _selectedDate = DateTime.now();
  String _selectedDuration = 'none';
  DateTime? _dueDate;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyDuration(String duration) {
    setState(() {
      _selectedDuration = duration;
      final base = _selectedDate;
      switch (duration) {
        case '1w':
          _dueDate = base.add(const Duration(days: 7));
          break;
        case '1m':
          _dueDate = DateTime(base.year, base.month + 1, base.day);
          break;
        case '3m':
          _dueDate = DateTime(base.year, base.month + 3, base.day);
          break;
        case '6m':
          _dueDate = DateTime(base.year, base.month + 6, base.day);
          break;
        case '1y':
          _dueDate = DateTime(base.year + 1, base.month, base.day);
          break;
        default:
          _dueDate = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  const Text(
                    'Add Debt / Loan (IOU)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    // Modern Visual Selector: "I Lent" vs "I Borrowed"
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => setState(() => _type = 'lent'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _type == 'lent'
                                    ? AppColors.income.withValues(alpha: 0.15)
                                    : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _type == 'lent' ? AppColors.income : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 20,
                                    color: _type == 'lent' ? AppColors.income : Colors.grey,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'I Lent',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: _type == 'lent' ? AppColors.income : null,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'They owe me',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _type == 'lent' ? AppColors.income : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => setState(() => _type = 'borrowed'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _type == 'borrowed'
                                    ? AppColors.expense.withValues(alpha: 0.15)
                                    : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _type == 'borrowed' ? AppColors.expense : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 20,
                                    color: _type == 'borrowed' ? AppColors.expense : Colors.grey,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'I Borrowed',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: _type == 'borrowed' ? AppColors.expense : null,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'I owe them',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _type == 'borrowed' ? AppColors.expense : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Name
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "Person's Name",
                        hintText: 'e.g. Alex Smith',
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Amount
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '${CurrencyFormatter.activeCurrencySymbol} ',
                        prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date Given / Borrowed
                    Material(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDate = picked;
                              if (_selectedDuration != 'none') {
                                _applyDuration(_selectedDuration);
                              }
                            });
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
                                  Text(
                                    _type == 'lent' ? 'Date Lent / Given' : 'Date Borrowed',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(_selectedDate),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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

                    // Tenure / Duration Quick Chips
                    const Text('For how long? (Tenure / Due Date)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('No Due Date', style: TextStyle(fontSize: 11)),
                          selected: _selectedDuration == 'none',
                          onSelected: (_) => _applyDuration('none'),
                        ),
                        ChoiceChip(
                          label: const Text('1 Week', style: TextStyle(fontSize: 11)),
                          selected: _selectedDuration == '1w',
                          onSelected: (_) => _applyDuration(_selectedDuration == '1w' ? 'none' : '1w'),
                        ),
                        ChoiceChip(
                          label: const Text('1 Month', style: TextStyle(fontSize: 11)),
                          selected: _selectedDuration == '1m',
                          onSelected: (_) => _applyDuration(_selectedDuration == '1m' ? 'none' : '1m'),
                        ),
                        ChoiceChip(
                          label: const Text('3 Months', style: TextStyle(fontSize: 11)),
                          selected: _selectedDuration == '3m',
                          onSelected: (_) => _applyDuration(_selectedDuration == '3m' ? 'none' : '3m'),
                        ),
                        ChoiceChip(
                          label: const Text('6 Months', style: TextStyle(fontSize: 11)),
                          selected: _selectedDuration == '6m',
                          onSelected: (_) => _applyDuration(_selectedDuration == '6m' ? 'none' : '6m'),
                        ),
                        ChoiceChip(
                          label: const Text('1 Year', style: TextStyle(fontSize: 11)),
                          selected: _selectedDuration == '1y',
                          onSelected: (_) => _applyDuration(_selectedDuration == '1y' ? 'none' : '1y'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Due Date
                    Material(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setState(() {
                              _dueDate = picked;
                              _selectedDuration = 'custom';
                            });
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.event_available_rounded, size: 20, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Expected Due Date', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text(
                                    _dueDate == null ? 'Not set (tap to pick)' : DateFormat('MMM d, yyyy').format(_dueDate!),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _dueDate == null ? Colors.grey : null,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              if (_dueDate != null)
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _dueDate = null;
                                    _selectedDuration = 'none';
                                  }),
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
                    const SizedBox(height: 12),

                    // Notes
                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes / Purpose (Optional)',
                        hintText: 'e.g. Lunch split, emergency, etc.',
                        prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Full-width Save Record Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = _nameController.text.trim();
                          final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
                          if (name.isEmpty || amount <= 0) return;

                          const uuid = Uuid();
                          await ref.read(debtRepositoryProvider).createDebt(
                                DebtsCompanion.insert(
                                  id: uuid.v4(),
                                  personName: name,
                                  amount: amount,
                                  type: _type,
                                  date: drift.Value(_selectedDate),
                                  dueDate: drift.Value(_dueDate),
                                  notes: drift.Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
                                ),
                              );
                          if (context.mounted) {
                            Navigator.pop(context);
                            Sonner.success(
                              'Recorded ${_type == "lent" ? "loan to" : "debt from"} $name',
                              description: CurrencyFormatter.format(amount),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _type == 'lent' ? AppColors.income : AppColors.expense,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Text('Save Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

class _RecordRepaymentSheet extends ConsumerStatefulWidget {
  final Debt debt;
  const _RecordRepaymentSheet({required this.debt});

  @override
  ConsumerState<_RecordRepaymentSheet> createState() => _RecordRepaymentSheetState();
}

class _RecordRepaymentSheetState extends ConsumerState<_RecordRepaymentSheet> {
  late final TextEditingController _settleController;
  final _notesController = TextEditingController();
  DateTime _repaymentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final remaining = widget.debt.amount - widget.debt.settledAmount;
    _settleController = TextEditingController(text: remaining > 0 ? remaining.toStringAsFixed(2) : '0.00');
  }

  @override
  void dispose() {
    _settleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remaining = widget.debt.amount - widget.debt.settledAmount;
    final isLent = widget.debt.type == 'lent';

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
                      color: (isLent ? AppColors.income : AppColors.expense).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLent ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      color: isLent ? AppColors.income : AppColors.expense,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Record Repayment', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text(widget.debt.personName, style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
                              const Text('Original Total', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(CurrencyFormatter.format(widget.debt.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Remaining Due', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyFormatter.format(remaining),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isLent ? AppColors.income : AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Amount
                    TextField(
                      controller: _settleController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Repayment Amount',
                        prefixText: '${CurrencyFormatter.activeCurrencySymbol} ',
                        prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick percentage chips if remaining > 0
                    if (remaining > 0) ...[
                      Row(
                        children: [
                          ActionChip(
                            label: const Text('25%'),
                            onPressed: () => setState(() => _settleController.text = (remaining * 0.25).toStringAsFixed(2)),
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            label: const Text('50%'),
                            onPressed: () => setState(() => _settleController.text = (remaining * 0.5).toStringAsFixed(2)),
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            label: const Text('Full Balance'),
                            onPressed: () => setState(() => _settleController.text = remaining.toStringAsFixed(2)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Date Picker
                    Material(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _repaymentDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() => _repaymentDate = picked);
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
                                  const Text('Repayment Date', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(_repaymentDate),
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

                    // Notes
                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Payment Note / Method (Optional)',
                        hintText: 'e.g. Bank transfer, cash, UPI',
                        prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Full-width confirm button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final amount = double.tryParse(_settleController.text.trim()) ?? 0.0;
                          if (amount <= 0) return;

                          await ref.read(debtRepositoryProvider).recordSettlement(
                                widget.debt.id,
                                amount,
                                date: _repaymentDate,
                                notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                              );
                          if (context.mounted) {
                            Navigator.pop(context);
                            Sonner.success(
                              'Repayment recorded for ${widget.debt.personName}',
                              description: CurrencyFormatter.format(amount),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Text('Confirm Repayment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
