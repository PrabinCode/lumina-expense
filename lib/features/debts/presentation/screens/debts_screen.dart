import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/debt_repository.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  bool _showSettled = false;

  void _showAddDebtDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String type = 'lent'; // 'lent' or 'borrowed'

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Debt / Loan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Lent (They Owe Me)')),
                            selected: type == 'lent',
                            selectedColor: AppColors.income.withValues(alpha: 0.2),
                            onSelected: (_) => setState(() => type = 'lent'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Borrowed (I Owe)')),
                            selected: type == 'borrowed',
                            selectedColor: AppColors.expense.withValues(alpha: 0.2),
                            onSelected: (_) => setState(() => type = 'borrowed'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Person Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notes / Reason (Optional)', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (name.isEmpty || amount <= 0) return;

                    const uuid = Uuid();
                    await ref.read(debtRepositoryProvider).createDebt(
                          DebtsCompanion.insert(
                            id: uuid.v4(),
                            personName: name,
                            amount: amount,
                            type: type,
                            notes: drift.Value(notesController.text.trim().isEmpty ? null : notesController.text.trim()),
                          ),
                        );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSettleDialog(Debt debt) {
    final remaining = debt.amount - debt.settledAmount;
    final settleController = TextEditingController(text: remaining.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Record Repayment for ${debt.personName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Outstanding balance: ${CurrencyFormatter.format(remaining)}'),
              const SizedBox(height: 12),
              TextField(
                controller: settleController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Repayment Amount',
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
                final amount = double.tryParse(settleController.text.trim()) ?? 0.0;
                if (amount <= 0) return;

                await ref.read(debtRepositoryProvider).recordSettlement(debt.id, amount);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Confirm Repayment'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
            Row(
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
                    child: const Column(
                      children: [
                        Icon(Icons.handshake_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No active debts or IOUs', style: TextStyle(fontWeight: FontWeight.w600)),
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

                    return Container(
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
                              isLent ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
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
