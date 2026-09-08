import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/privacy_mask_provider.dart';
import '../../../../core/services/receipt_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sonner_toast.dart';
import '../../../recycle_bin/data/recycle_bin_repository.dart';
import '../../data/transaction_repository.dart';
import '../screens/add_transaction_sheet.dart';
import 'receipt_viewer_dialog.dart';

class TransactionDetailSheet extends ConsumerWidget {
  final TransactionWithDetails item;
  final VoidCallback? onDeleted;
  final VoidCallback? onEdited;

  const TransactionDetailSheet({
    super.key,
    required this.item,
    this.onDeleted,
    this.onEdited,
  });

  static Future<void> show(
    BuildContext context,
    TransactionWithDetails item, {
    VoidCallback? onDeleted,
    VoidCallback? onEdited,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => TransactionDetailSheet(
        item: item,
        onDeleted: onDeleted,
        onEdited: onEdited,
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final tx = item.transaction;
    final nav = Navigator.of(context);
    final recycleRepo = ref.read(recycleBinRepositoryProvider);

    nav.pop();
    onDeleted?.call();

    final recycleId = await recycleRepo.moveTransactionToRecycleBin(tx.id);

    Sonner.success(
      'Moved "${tx.title}" to Trash',
      description: 'You can restore this anytime from Settings > Recycle Bin',
      undoLabel: 'UNDO',
      onUndo: () async {
        if (recycleId.isNotEmpty) {
          await recycleRepo.restoreItem(recycleId);
          Sonner.success('Restored "${tx.title}"');
        }
      },
    );
  }

  void _handleEdit(BuildContext context) {
    final tx = item.transaction;
    Navigator.of(context).pop();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
        initialType: tx.type,
        transactionToEdit: tx,
        initialSplits: item.splits,
      ),
    ).then((_) {
      onEdited?.call();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = item.transaction;
    final cat = item.category;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMasked = ref.watch(privacyMaskProvider);

    Color amountColor;
    String typeLabel;
    IconData typeIcon;
    Color typeColor;

    if (tx.isSplit) {
      amountColor = AppColors.expense;
      typeLabel = 'Split Expense (${item.splits.length} categories)';
      typeIcon = Icons.call_split_rounded;
      typeColor = AppColors.warning;
    } else if (tx.type == 'income') {
      amountColor = AppColors.income;
      typeLabel = 'Income • ${cat?.name ?? "General"}';
      typeIcon = IconHelper.getCategoryIcon(cat?.icon ?? 'payments');
      typeColor = cat != null ? Color(cat.color) : AppColors.income;
    } else if (tx.type == 'expense') {
      amountColor = AppColors.expense;
      typeLabel = 'Expense • ${cat?.name ?? "General"}';
      typeIcon = IconHelper.getCategoryIcon(cat?.icon ?? 'shopping_bag');
      typeColor = cat != null ? Color(cat.color) : AppColors.expense;
    } else {
      amountColor = AppColors.transfer;
      typeLabel = 'Account Transfer';
      typeIcon = Icons.swap_horiz_rounded;
      typeColor = AppColors.transfer;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
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

          // Header Badge & Amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(typeIcon, color: typeColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${tx.type == "income" ? "+" : (tx.type == "expense" ? "-" : "")}${CurrencyFormatter.format(tx.amount, mask: isMasked)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: amountColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Metadata Info Row (Account & Date/Time)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.account_balance_wallet_outlined, size: 16, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Text('Account:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tx.type == 'transfer' && item.toAccount != null
                            ? '${item.account.name} → ${item.toAccount!.name}'
                            : item.account.name,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('Date & Time:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        DateFormat('EEE, MMM d, yyyy • h:mm a').format(tx.date),
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Note if present
          if (tx.note != null && tx.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border(
                  left: BorderSide(color: AppColors.primary, width: 3),
                ),
              ),
              child: Text(
                tx.note!,
                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ),
          ],

          // Hashtag Tags if present
          if (tx.tags != null && tx.tags!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tx.tags!.split(',').where((t) => t.trim().isNotEmpty).map((tag) {
                final cleaned = tag.trim().startsWith('#') ? tag.trim() : '#${tag.trim()}';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    cleaned,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Itemized Category Splits
          if (tx.isSplit && item.splits.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Itemized Splits Breakdown',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: item.splits.map((s) {
                  final sc = s.category;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(IconHelper.getCategoryIcon(sc.icon), size: 16, color: Color(sc.color)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sc.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              if (s.split.note != null && s.split.note!.isNotEmpty)
                                Text(s.split.note!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(s.split.amount, mask: isMasked),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Attached Receipt preview button
          if (tx.receiptPath != null && tx.receiptPath!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildReceiptPreview(context, ref, tx.receiptPath!, tx.title, isDark),
          ],

          const SizedBox(height: 24),

          // Primary Actions: Move to Trash & Edit Transaction
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Move to Trash'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.expense,
                    side: const BorderSide(color: AppColors.expense),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _handleDelete(context, ref),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit Transaction'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () => _handleEdit(context),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 6),
        ],
      ),
    );
  }

  Widget _buildReceiptPreview(
    BuildContext context,
    WidgetRef ref,
    String receiptPath,
    String title,
    bool isDark,
  ) {
    return FutureBuilder<File?>(
      future: ref.read(receiptStorageServiceProvider).resolveReceiptFile(receiptPath),
      builder: (context, snapshot) {
        final file = snapshot.data;
        return Material(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () {
              ReceiptViewerDialog.show(
                context,
                receiptPath: receiptPath,
                title: title,
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: file != null && file.existsSync()
                        ? Image.file(
                            file,
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 38,
                            height: 38,
                            color: AppColors.primary.withValues(alpha: 0.15),
                            child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                          ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Receipt Attached',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Tap to inspect & zoom image',
                          style: TextStyle(fontSize: 11, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.zoom_in_rounded, color: AppColors.primary, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
