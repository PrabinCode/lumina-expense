import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../data/category_repository.dart';

class CategoryDeleteResult {
  final bool shouldDelete;
  final String? targetCategoryId;
  final bool deleteAssociatedBudget;

  const CategoryDeleteResult({
    required this.shouldDelete,
    this.targetCategoryId,
    this.deleteAssociatedBudget = true,
  });
}

class CategoryReassignmentDialog extends StatefulWidget {
  final Category category;
  final CategoryUsageInfo usage;
  final List<Category> availableCategories;

  const CategoryReassignmentDialog({
    super.key,
    required this.category,
    required this.usage,
    required this.availableCategories,
  });

  static Future<CategoryDeleteResult?> show(
    BuildContext context, {
    required Category category,
    required CategoryUsageInfo usage,
    required List<Category> availableCategories,
  }) {
    return showDialog<CategoryDeleteResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CategoryReassignmentDialog(
        category: category,
        usage: usage,
        availableCategories: availableCategories,
      ),
    );
  }

  @override
  State<CategoryReassignmentDialog> createState() => _CategoryReassignmentDialogState();
}

class _CategoryReassignmentDialogState extends State<CategoryReassignmentDialog> {
  late bool _reassign;
  String? _selectedTargetId;
  bool _deleteBudget = true;

  @override
  void initState() {
    super.initState();
    // Default to reassign if other categories exist
    _reassign = widget.availableCategories.isNotEmpty;
    if (_reassign) {
      _selectedTargetId = widget.availableCategories.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor = Color(widget.category.color);
    final isExpense = widget.category.type == 'expense';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      actionsPadding: const EdgeInsets.fromLTRB(16, 10, 20, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(IconHelper.getIcon(widget.category.icon), color: catColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete "${widget.category.name}"?',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isExpense ? 'Expense' : 'Income'} Category',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Usage Stat Strip
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                      SizedBox(width: 6),
                      Text(
                        'Category Currently In Use',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (widget.usage.transactionCount > 0)
                        _buildUsagePill(
                          Icons.receipt_long_rounded,
                          '${widget.usage.transactionCount} transaction${widget.usage.transactionCount > 1 ? 's' : ''}',
                          isDark,
                        ),
                      if (widget.usage.splitCount > 0)
                        _buildUsagePill(
                          Icons.call_split_rounded,
                          '${widget.usage.splitCount} split line${widget.usage.splitCount > 1 ? 's' : ''}',
                          isDark,
                        ),
                      if (widget.usage.budgetCount > 0)
                        _buildUsagePill(
                          Icons.pie_chart_outline_rounded,
                          '${widget.usage.budgetCount} budget',
                          isDark,
                        ),
                      if (widget.usage.recurringCount > 0)
                        _buildUsagePill(
                          Icons.autorenew_rounded,
                          '${widget.usage.recurringCount} subscription${widget.usage.recurringCount > 1 ? 's' : ''}',
                          isDark,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            if (widget.category.isDefault) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'This is a default Lumina category. You can restore it anytime from the Recycle Bin.',
                        style: TextStyle(fontSize: 10.5, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Text(
              'Choose how to handle existing data:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            // Option 1: Reassign
            if (widget.availableCategories.isNotEmpty) ...[
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _reassign = true),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _reassign ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _reassign ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _reassign ? AppColors.primary : Colors.grey,
                                width: 2,
                              ),
                            ),
                            child: _reassign
                                ? Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Reassign to another category (Recommended)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      if (_reassign) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedTargetId,
                              items: widget.availableCategories.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c.id,
                                  child: Row(
                                    children: [
                                      Icon(IconHelper.getIcon(c.icon), size: 16, color: Color(c.color)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          c.name,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (newId) {
                                if (newId != null) {
                                  setState(() => _selectedTargetId = newId);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Option 2: Leave Uncategorized
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _reassign = false),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: !_reassign ? AppColors.expense.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !_reassign ? AppColors.expense : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: !_reassign ? AppColors.expense : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: !_reassign
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.expense,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Leave as Uncategorized',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Transactions will remain intact but will display as "General / Uncategorized".',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Budget deletion checkbox if budget exists
            if (widget.usage.budgetCount > 0) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _deleteBudget,
                onChanged: (val) => setState(() => _deleteBudget = val ?? true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.expense,
                title: const Text(
                  'Delete active budget for this category',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Prevents orphaned budget spending limits',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.expense,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () {
            Navigator.pop(
              context,
              CategoryDeleteResult(
                shouldDelete: true,
                targetCategoryId: _reassign ? _selectedTargetId : null,
                deleteAssociatedBudget: _deleteBudget,
              ),
            );
          },
          child: const Text('Delete & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildUsagePill(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.warning),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
