import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../accounts/data/account_repository.dart';
import '../../../categories/data/category_repository.dart';
import '../../data/transaction_repository.dart';

class TransactionBatchActionBar extends ConsumerWidget {
  final Set<String> selectedIds;
  final VoidCallback onClearSelection;
  final VoidCallback onSelectAll;
  final bool isAllSelected;

  const TransactionBatchActionBar({
    super.key,
    required this.selectedIds,
    required this.onClearSelection,
    required this.onSelectAll,
    required this.isAllSelected,
  });

  Future<void> _showBatchCategoryDialog(BuildContext context, WidgetRef ref) async {
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 transaction'), duration: Duration(seconds: 2)),
      );
      return;
    }

    final categories = await ref.read(categoriesStreamProvider(null).future);
    if (!context.mounted) return;

    final selectedCategory = await showModalBottomSheet<Category>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assign Category to Selected',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final cat = categories[i];
                    return ListTile(
                      leading: Icon(IconHelper.getIcon(cat.icon), color: Color(cat.color)),
                      title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () => Navigator.pop(ctx, cat),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedCategory != null) {
      await ref.read(transactionRepositoryProvider).batchUpdateCategory(
            selectedIds.toList(),
            selectedCategory.id,
          );
      onClearSelection();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated category to "${selectedCategory.name}" for ${selectedIds.length} items')),
        );
      }
    }
  }

  Future<void> _showBatchAccountDialog(BuildContext context, WidgetRef ref) async {
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 transaction'), duration: Duration(seconds: 2)),
      );
      return;
    }

    final accounts = await ref.read(accountsStreamProvider.future);
    if (!context.mounted) return;

    final selectedAccount = await showModalBottomSheet<Account>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assign Account to Selected',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: accounts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final acc = accounts[i];
                    return ListTile(
                      leading: Icon(IconHelper.getIcon(acc.icon), color: Color(acc.color)),
                      title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${acc.currency} • ${acc.type}'),
                      onTap: () => Navigator.pop(ctx, acc),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedAccount != null) {
      await ref.read(transactionRepositoryProvider).batchUpdateAccount(
            selectedIds.toList(),
            selectedAccount.id,
          );
      onClearSelection();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reassigned to account "${selectedAccount.name}" for ${selectedIds.length} items')),
        );
      }
    }
  }

  Future<void> _showBatchTagDialog(BuildContext context, WidgetRef ref) async {
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 transaction'), duration: Duration(seconds: 2)),
      );
      return;
    }

    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Tag to Selected'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. vacation, tax-deductible',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Add Tag'),
            ),
          ],
        );
      },
    );

    if (tag != null && tag.isNotEmpty) {
      await ref.read(transactionRepositoryProvider).batchAddTag(selectedIds.toList(), tag);
      onClearSelection();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added tag "$tag" to ${selectedIds.length} items')),
        );
      }
    }
  }

  Future<void> _confirmBatchDelete(BuildContext context, WidgetRef ref) async {
    final count = selectedIds.length;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 transaction to delete'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppColors.expense, size: 24),
            SizedBox(width: 8),
            Text('Delete Selected?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete $count selected transaction${count > 1 ? "s" : ""}?\n\nThis will remove them completely and update all account balances.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete ($count)'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(transactionRepositoryProvider);
      final ids = selectedIds.toList();
      final snapshots = await repo.getBatchTransactionSnapshots(ids);
      final deleted = await repo.batchDeleteTransactions(ids);
      onClearSelection();

      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('🗑️ Deleted $deleted transaction${deleted > 1 ? "s" : ""}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.amber,
              onPressed: () async {
                await repo.restoreBatchTransactionSnapshots(snapshots);
                messenger.clearSnackBars();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('✓ Restored $deleted transaction${deleted > 1 ? "s" : ""}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        );
      }
    }


  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSelection = selectedIds.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasSelection ? AppColors.primary.withValues(alpha: 0.5) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: hasSelection ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cancel Selection Button
          _buildCompactButton(
            icon: Icons.close_rounded,
            tooltip: 'Cancel selection',
            onTap: onClearSelection,
            isDark: isDark,
          ),
          const SizedBox(width: 4),

          // Count Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasSelection ? AppColors.primary.withValues(alpha: 0.18) : Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${selectedIds.length}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: hasSelection ? AppColors.primary : Colors.grey,
              ),
            ),
          ),

          const Spacer(),

          // Select All / Deselect All
          _buildCompactButton(
            icon: isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
            tooltip: isAllSelected ? 'Deselect All' : 'Select All',
            onTap: onSelectAll,
            isDark: isDark,
          ),
          const SizedBox(width: 2),

          // Category Button
          _buildCompactButton(
            icon: Icons.category_outlined,
            tooltip: 'Change Category',
            onTap: () => _showBatchCategoryDialog(context, ref),
            isDark: isDark,
          ),
          const SizedBox(width: 2),

          // Account Button
          _buildCompactButton(
            icon: Icons.account_balance_wallet_outlined,
            tooltip: 'Change Account / Wallet',
            onTap: () => _showBatchAccountDialog(context, ref),
            isDark: isDark,
          ),
          const SizedBox(width: 2),

          // Tag Button
          _buildCompactButton(
            icon: Icons.label_outline_rounded,
            tooltip: 'Add Tag',
            onTap: () => _showBatchTagDialog(context, ref),
            isDark: isDark,
          ),
          const SizedBox(width: 2),

          // Delete Button (Highlighted with red accent)
          _buildCompactButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Delete Selected',
            onTap: () => _confirmBatchDelete(context, ref),
            isDark: isDark,
            iconColor: AppColors.expense,
            bgColor: hasSelection ? AppColors.expense.withValues(alpha: 0.15) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
    Color? iconColor,
    Color? bgColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bgColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(
              icon,
              size: 19,
              color: iconColor ?? (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}
