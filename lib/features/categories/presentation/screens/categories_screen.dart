import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../data/category_repository.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _availableIcons = [
    'restaurant',
    'shopping_cart',
    'directions_car',
    'home',
    'receipt_long',
    'movie',
    'shopping_bag',
    'medical_services',
    'school',
    'spa',
    'flight',
    'payments',
    'work',
    'trending_up',
    'card_giftcard',
    'account_balance_wallet',
  ];

  final List<int> _availableColors = [
    0xFF10B981, // Emerald
    0xFFEF4444, // Red
    0xFF3B82F6, // Blue
    0xFFF59E0B, // Amber
    0xFF8B5CF6, // Purple
    0xFFEC4899, // Pink
    0xFF06B6D4, // Cyan
    0xFFF97316, // Orange
    0xFF6366F1, // Indigo
    0xFF14B8A6, // Teal
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddEditCategoryDialog({Category? categoryToEdit, required String type}) {
    final nameController = TextEditingController(text: categoryToEdit?.name ?? '');
    String selectedIcon = categoryToEdit?.icon ?? (_availableIcons.first);
    int selectedColor = categoryToEdit?.color ?? (_availableColors.first);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                categoryToEdit == null ? 'Add Category' : 'Edit Category',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        hintText: 'e.g. Groceries, Freelance',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Select Icon', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableIcons.map((iconName) {
                        final isSelected = selectedIcon == iconName;
                        return InkWell(
                          onTap: () => setDialogState(() => selectedIcon = iconName),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.2)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              IconHelper.getIcon(iconName),
                              size: 22,
                              color: isSelected ? AppColors.primary : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Select Color', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableColors.map((colorVal) {
                        final isSelected = selectedColor == colorVal;
                        return InkWell(
                          onTap: () => setDialogState(() => selectedColor = colorVal),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(colorVal),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Color(colorVal).withValues(alpha: 0.5),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    final repo = ref.read(categoryRepositoryProvider);

                    if (categoryToEdit == null) {
                      await repo.createCategory(
                        CategoriesCompanion.insert(
                          id: const Uuid().v4(),
                          name: name,
                          type: type,
                          icon: drift.Value(selectedIcon),
                          color: drift.Value(selectedColor),
                          isDefault: const drift.Value(false),
                        ),
                      );
                    } else {
                      await repo.updateCategory(
                        CategoriesCompanion(
                          id: drift.Value(categoryToEdit.id),
                          name: drift.Value(name),
                          type: drift.Value(categoryToEdit.type),
                          icon: drift.Value(selectedIcon),
                          color: drift.Value(selectedColor),
                          isDefault: drift.Value(categoryToEdit.isDefault),
                        ),
                      );
                    }

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(categoryToEdit == null ? 'Create' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCategory(Category category) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete "${category.name}"?'),
          content: const Text(
            'Are you sure you want to delete this category? Existing transactions with this category will remain, but the category itself will be removed.',
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
              ),
              onPressed: () async {
                await ref.read(categoryRepositoryProvider).deleteCategory(category.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories & Reordering'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          tabs: const [
            Tab(text: 'Expense Categories', icon: Icon(Icons.arrow_upward_rounded, size: 18)),
            Tab(text: 'Income Categories', icon: Icon(Icons.arrow_downward_rounded, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CategoryListView(
            type: 'expense',
            onEdit: (cat) => _showAddEditCategoryDialog(categoryToEdit: cat, type: 'expense'),
            onDelete: _confirmDeleteCategory,
          ),
          _CategoryListView(
            type: 'income',
            onEdit: (cat) => _showAddEditCategoryDialog(categoryToEdit: cat, type: 'income'),
            onDelete: _confirmDeleteCategory,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final type = _tabController.index == 0 ? 'expense' : 'income';
          _showAddEditCategoryDialog(type: type);
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _CategoryListView extends ConsumerWidget {
  final String type;
  final Function(Category) onEdit;
  final Function(Category) onDelete;

  const _CategoryListView({
    required this.type,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider(type));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.category_outlined, size: 56, color: Colors.grey.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(
                  'No $type categories yet',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.drag_indicator_rounded, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Drag & hold to reorder categories',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: categories.length,
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final list = List<Category>.from(categories);
                  final item = list.removeAt(oldIndex);
                  list.insert(newIndex, item);

                  final idList = list.map((c) => c.id).toList();
                  ref.read(categoryRepositoryProvider).saveCategoryOrder(idList, type);
                },
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final catColor = Color(cat.color);

                  return Container(
                    key: ValueKey(cat.id),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(IconHelper.getIcon(cat.icon), color: catColor, size: 20),
                      ),
                      title: Text(
                        cat.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: Text(
                        cat.isDefault ? 'Default Category' : 'Custom Category',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => onEdit(cat),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expense),
                            onPressed: () => onDelete(cat),
                            tooltip: 'Delete',
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.drag_handle_rounded, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}
