import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../accounts/data/account_repository.dart';
import '../../../categories/data/category_repository.dart';
import '../../../recycle_bin/data/recycle_bin_repository.dart';
import '../../../../core/widgets/sonner_toast.dart';
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

    final tag = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BatchAddTagSheet(count: selectedIds.length),
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
      final recycleRepo = ref.read(recycleBinRepositoryProvider);
      final ids = selectedIds.toList();
      final count = ids.length;
      final recycleIds = await recycleRepo.moveBatchTransactionsToRecycleBin(ids);
      onClearSelection();

      Sonner.success(
        'Moved $count transaction${count > 1 ? "s" : ""} to Recycle Bin',
        description: 'Tap undo to restore or manage in Settings > Recycle Bin',
        undoLabel: 'UNDO',
        duration: const Duration(seconds: 5),
        onUndo: () async {
          await recycleRepo.restoreBatch(recycleIds);
          Sonner.success('Restored $count transaction${count > 1 ? "s" : ""}');
        },
      );
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

class _BatchAddTagSheet extends StatefulWidget {
  final int count;

  const _BatchAddTagSheet({required this.count});

  @override
  State<_BatchAddTagSheet> createState() => _BatchAddTagSheetState();
}

class _BatchAddTagSheetState extends State<_BatchAddTagSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      Navigator.pop(context, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
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
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.label_outline_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Tag to Selected',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          'Applying to ${widget.count} selected item${widget.count > 1 ? "s" : ""}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
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
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. vacation, tax-deductible',
                  labelText: 'Tag Name',
                  prefixIcon: const Icon(Icons.tag_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _submit,
                child: const Text('Add Tag', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
