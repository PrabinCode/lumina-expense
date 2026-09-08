import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/currency_provider.dart';
import '../../../../core/providers/privacy_mask_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/utils/query_parser.dart';
import '../../../../core/widgets/bouncy.dart';
import '../../../../core/widgets/sonner_toast.dart';
import '../../../recycle_bin/data/recycle_bin_repository.dart';
import '../../../transactions/data/transaction_repository.dart';
import '../../../transactions/presentation/screens/add_transaction_sheet.dart';
import '../../../transactions/presentation/widgets/power_search_bar.dart';
import '../../../transactions/presentation/widgets/transaction_batch_action_bar.dart';
import '../../../transactions/presentation/widgets/transaction_detail_sheet.dart';

class RecentTransactionsList extends ConsumerStatefulWidget {
  const RecentTransactionsList({super.key});

  @override
  ConsumerState<RecentTransactionsList> createState() => _RecentTransactionsListState();
}

class _RecentTransactionsListState extends ConsumerState<RecentTransactionsList> {
  String _searchQuery = '';
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;
  bool _isSearchExpanded = false;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  void _selectAll(List<TransactionWithDetails> transactions) {
    setState(() {
      if (_selectedIds.length == transactions.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(transactions.map((t) => t.transaction.id));
        _isSelectionMode = true;
      }
    });
  }

  void _showTransactionDetails(BuildContext context, TransactionWithDetails item) {
    TransactionDetailSheet.show(context, item);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currencyProvider);
    final isMasked = ref.watch(privacyMaskProvider);
    final transactionsAsync = ref.watch(recentTransactionsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Recent Transactions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                _isSearchExpanded ? Icons.filter_list_off_rounded : Icons.search_rounded,
                size: 20,
                color: _searchQuery.isNotEmpty ? AppColors.primary : null,
              ),
              tooltip: 'Search & Filter',
              onPressed: () => setState(() {
                _isSearchExpanded = !_isSearchExpanded;
                if (!_isSearchExpanded) _searchQuery = '';
              }),
            ),
            if (!_isSelectionMode)
              IconButton(
                icon: const Icon(Icons.checklist_rounded, size: 20),
                tooltip: 'Select multiple',
                onPressed: () => setState(() => _isSelectionMode = true),
              ),
          ],
        ),
        if (_isSearchExpanded) ...[
          const SizedBox(height: 8),
          PowerSearchBar(
            query: _searchQuery,
            onQueryChanged: (q) => setState(() => _searchQuery = q),
            onClear: () => setState(() => _searchQuery = ''),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        transactionsAsync.when(
          data: (allTransactions) {
            final filteredTransactions = _searchQuery.trim().isEmpty
                ? allTransactions
                : allTransactions.where((t) => QueryParser.evaluate(_searchQuery, t)).toList();

            if (filteredTransactions.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.receipt_long_outlined,
                      size: 44,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isNotEmpty ? 'No matching transactions' : 'No transactions yet',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Try refining your query or operators'
                          : 'Tap + Expense or + Income to record your first transaction.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                if (_isSelectionMode) ...[
                  TransactionBatchActionBar(
                    selectedIds: _selectedIds,
                    onClearSelection: _clearSelection,
                    onSelectAll: () => _selectAll(filteredTransactions),
                    isAllSelected: _selectedIds.length == filteredTransactions.length && filteredTransactions.isNotEmpty,
                  ),
                  const SizedBox(height: 10),
                ],
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredTransactions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = filteredTransactions[index];
                    final tx = item.transaction;
                    final cat = item.category;
                    final isSelected = _selectedIds.contains(tx.id);

                    Color amountColor;
                    String prefix;
                    IconData icon;
                    Color iconColor;

                    if (tx.isSplit) {
                      amountColor = AppColors.expense;
                      prefix = '-';
                      icon = Icons.call_split_rounded;
                      iconColor = AppColors.warning;
                    } else if (tx.type == 'income') {
                      amountColor = AppColors.income;
                      prefix = '+';
                      icon = IconHelper.getIcon(cat?.icon ?? 'payments');
                      iconColor = cat != null ? Color(cat.color) : AppColors.income;
                    } else if (tx.type == 'expense') {
                      amountColor = AppColors.expense;
                      prefix = '-';
                      icon = IconHelper.getIcon(cat?.icon ?? 'shopping_bag');
                      iconColor = cat != null ? Color(cat.color) : AppColors.expense;
                    } else {
                      amountColor = AppColors.transfer;
                      prefix = '';
                      icon = Icons.swap_horiz_rounded;
                      iconColor = AppColors.transfer;
                    }

                    return Dismissible(
                      key: Key(tx.id),
                      direction: _isSelectionMode ? DismissDirection.none : DismissDirection.horizontal,
                      background: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_rounded, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Edit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      secondaryBackground: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          color: AppColors.expense,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Icon(Icons.delete_outline, color: Colors.white),
                          ],
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => AddTransactionSheet(
                              initialType: tx.type,
                              transactionToEdit: tx,
                              initialSplits: item.splits,
                            ),
                          );
                          return false;
                        }
                        return true;
                      },
                      onDismissed: (direction) async {
                        if (direction == DismissDirection.endToStart) {
                          final recycleRepo = ref.read(recycleBinRepositoryProvider);
                          final recycleId = await recycleRepo.moveTransactionToRecycleBin(tx.id);

                          Sonner.success(
                            'Moved "${tx.title}" to Recycle Bin',
                            description: 'Tap undo to restore or find it in Settings > Recycle Bin',
                            undoLabel: 'UNDO',
                            onUndo: () async {
                              if (recycleId.isNotEmpty) {
                                await recycleRepo.restoreItem(recycleId);
                                Sonner.success('Restored "${tx.title}"');
                              }
                            },
                          );
                        }
                      },

                      child: Bouncy(
                        pressedScale: 0.98,
                        enableHaptics: true,
                        onLongPress: () => _toggleSelection(tx.id),
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(tx.id);
                          } else {
                            _showTransactionDetails(context, item);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                            child: Row(
                              children: [
                                if (_isSelectionMode)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Icon(
                                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                      color: isSelected ? AppColors.primary : Colors.grey,
                                      size: 22,
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(icon, color: iconColor, size: 22),
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
                                              tx.title,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (tx.isSplit) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.warning.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Split (${item.splits.length})',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${item.account.name}${item.toAccount != null ? ' → ${item.toAccount!.name}' : ''}  •  ${DateFormat('MMM d').format(tx.date)}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                              ),
                                            ),
                                          ),
                                          if (tx.receiptPath != null && tx.receiptPath!.isNotEmpty) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.receipt_outlined,
                                              size: 13,
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$prefix${CurrencyFormatter.format(tx.amount, mask: isMasked)}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: amountColor,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
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
          error: (err, _) => Text('Error loading transactions: $err'),
        ),
      ],
    );
  }
}
