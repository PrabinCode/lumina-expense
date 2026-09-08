import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/privacy_mask_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/bouncy.dart';
import '../../../../core/widgets/sonner_toast.dart';
import '../../../recycle_bin/data/recycle_bin_repository.dart';
import '../../data/transaction_repository.dart';
import '../screens/add_transaction_sheet.dart';
import 'transaction_detail_sheet.dart';

class InteractiveTransactionTile extends ConsumerWidget {
  final TransactionWithDetails item;
  final VoidCallback? onDeleted;
  final VoidCallback? onEdited;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<String>? onSelectionToggle;

  const InteractiveTransactionTile({
    super.key,
    required this.item,
    this.onDeleted,
    this.onEdited,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectionToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = item.transaction;
    final cat = item.category;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMasked = ref.watch(privacyMaskProvider);

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
      icon = IconHelper.getCategoryIcon(cat?.icon ?? 'payments');
      iconColor = cat != null ? Color(cat.color) : AppColors.income;
    } else if (tx.type == 'expense') {
      amountColor = AppColors.expense;
      prefix = '-';
      icon = IconHelper.getCategoryIcon(cat?.icon ?? 'shopping_bag');
      iconColor = cat != null ? Color(cat.color) : AppColors.expense;
    } else {
      amountColor = AppColors.transfer;
      prefix = '';
      icon = Icons.swap_horiz_rounded;
      iconColor = AppColors.transfer;
    }

    return Dismissible(
      key: Key(tx.id),
      direction: isSelectionMode ? DismissDirection.none : DismissDirection.horizontal,
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
            Text('Trash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right to edit
          await showModalBottomSheet<void>(
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
          onEdited?.call();
          return false;
        }
        return true;
      },
      onDismissed: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Swipe left to trash
          onDeleted?.call();
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
        onLongPress: () {
          if (onSelectionToggle != null) {
            onSelectionToggle!(tx.id);
          } else {
            TransactionDetailSheet.show(
              context,
              item,
              onDeleted: onDeleted,
              onEdited: onEdited,
            );
          }
        },
        onTap: () {
          if (isSelectionMode && onSelectionToggle != null) {
            onSelectionToggle!(tx.id);
          } else {
            TransactionDetailSheet.show(
              context,
              item,
              onDeleted: onDeleted,
              onEdited: onEdited,
            );
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
              if (isSelectionMode)
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
                        if (tx.receiptPath != null && tx.receiptPath!.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.receipt_long_rounded, size: 14, color: AppColors.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.account.name}${item.toAccount != null ? ' → ${item.toAccount!.name}' : ''}  •  ${DateFormat('MMM d').format(tx.date)}',
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$prefix${CurrencyFormatter.format(tx.amount, mask: isMasked)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
