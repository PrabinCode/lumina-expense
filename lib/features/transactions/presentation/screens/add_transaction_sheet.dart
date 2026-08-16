import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../accounts/data/account_repository.dart';
import '../../../categories/data/category_repository.dart';
import '../../data/transaction_repository.dart';
import '../widgets/num_keypad.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  final String initialType; // 'expense', 'income', 'transfer'

  const AddTransactionSheet({super.key, this.initialType = 'expense'});

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  late String _type;
  String _amountStr = '0';
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedCategoryId;
  String? _selectedAccountId;
  String? _selectedToAccountId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onKeypadPress(String val) {
    setState(() {
      if (_amountStr == '0' && val != '.') {
        _amountStr = val;
      } else if (val == '.' && _amountStr.contains('.')) {
        return; // Prevent multiple decimal points
      } else if (_amountStr.contains('.') && _amountStr.split('.')[1].length >= 2) {
        return; // Max 2 decimal digits
      } else {
        _amountStr += val;
      }
    });
  }

  void _onKeypadDelete() {
    setState(() {
      if (_amountStr.length > 1) {
        _amountStr = _amountStr.substring(0, _amountStr.length - 1);
      } else {
        _amountStr = '0';
      }
    });
  }

  void _onKeypadClear() {
    setState(() {
      _amountStr = '0';
    });
  }

  Future<void> _saveTransaction() async {
    final amount = double.tryParse(_amountStr) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount greater than 0')),
      );
      return;
    }

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account')),
      );
      return;
    }

    if (_type == 'transfer' && _selectedToAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select destination account for transfer')),
      );
      return;
    }

    if (_type == 'transfer' && _selectedAccountId == _selectedToAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Source and destination accounts must be different')),
      );
      return;
    }

    String title = _titleController.text.trim();
    if (title.isEmpty) {
      if (_type == 'transfer') {
        title = 'Account Transfer';
      } else {
        title = _type == 'expense' ? 'Expense' : 'Income';
      }
    }

    const uuid = Uuid();
    final companion = TransactionsCompanion.insert(
      id: uuid.v4(),
      title: title,
      amount: amount,
      type: _type,
      categoryId: drift.Value(_selectedCategoryId),
      accountId: _selectedAccountId!,
      toAccountId: drift.Value(_selectedToAccountId),
      date: drift.Value(_selectedDate),
      note: drift.Value(_noteController.text.trim().isEmpty ? null : _noteController.text.trim()),
    );

    await ref.read(transactionRepositoryProvider).createTransaction(companion);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider(_type == 'transfer' ? null : _type));

    // Default account selection if not set
    accountsAsync.whenData((accounts) {
      if (_selectedAccountId == null && accounts.isNotEmpty) {
        _selectedAccountId = accounts.first.id;
        if (_type == 'transfer' && accounts.length > 1 && _selectedToAccountId == null) {
          _selectedToAccountId = accounts[1].id;
        }
      }
    });

    Color primaryTypeColor;
    if (_type == 'expense') {
      primaryTypeColor = AppColors.expense;
    } else if (_type == 'income') {
      primaryTypeColor = AppColors.income;
    } else {
      primaryTypeColor = AppColors.transfer;
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header handle
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

          // Type Switcher Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _buildTypeTab('expense', 'Expense', AppColors.expense),
                  _buildTypeTab('income', 'Income', AppColors.income),
                  _buildTypeTab('transfer', 'Transfer', AppColors.transfer),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Amount Display Area
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: primaryTypeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryTypeColor.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '\$ ',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryTypeColor,
                  ),
                ),
                Text(
                  _amountStr,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: primaryTypeColor,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title / Description
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: _type == 'transfer' ? 'Transfer Note (Optional)' : 'Title / What was this for?',
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Account Selector
                  Row(
                    children: [
                      Expanded(
                        child: accountsAsync.when(
                          data: (accounts) {
                            return DropdownButtonFormField<String>(
                              initialValue: _selectedAccountId,
                              decoration: InputDecoration(
                                labelText: _type == 'transfer' ? 'From Account' : 'Account',
                                filled: true,
                                fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: accounts.map((acc) {
                                return DropdownMenuItem(
                                  value: acc.id,
                                  child: Row(
                                    children: [
                                      Icon(IconHelper.getIcon(acc.icon), size: 18, color: Color(acc.color)),
                                      const SizedBox(width: 8),
                                      Text(acc.name, style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedAccountId = val),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                      ),
                      if (_type == 'transfer') ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: accountsAsync.when(
                            data: (accounts) {
                              return DropdownButtonFormField<String>(
                                initialValue: _selectedToAccountId,
                                decoration: InputDecoration(
                                  labelText: 'To Account',
                                  filled: true,
                                  fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: accounts.map((acc) {
                                  return DropdownMenuItem(
                                    value: acc.id,
                                    child: Row(
                                      children: [
                                        Icon(IconHelper.getIcon(acc.icon), size: 18, color: Color(acc.color)),
                                        const SizedBox(width: 8),
                                        Text(acc.name, style: const TextStyle(fontSize: 13)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedToAccountId = val),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Category Selector (if not transfer)
                  if (_type != 'transfer') ...[
                    const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    categoriesAsync.when(
                      data: (categories) {
                        return SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final isSelected = _selectedCategoryId == cat.id;
                              return ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      IconHelper.getIcon(cat.icon),
                                      size: 16,
                                      color: isSelected ? Colors.white : Color(cat.color),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(cat.name),
                                  ],
                                ),
                                selected: isSelected,
                                selectedColor: Color(cat.color),
                                onSelected: (sel) {
                                  setState(() {
                                    _selectedCategoryId = sel ? cat.id : null;
                                  });
                                },
                              );
                            },
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Date Row
                  Material(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            const Text('Change', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Keypad
                  NumKeypad(
                    onKeyPressed: _onKeypadPress,
                    onDelete: _onKeypadDelete,
                    onClear: _onKeypadClear,
                  ),

                  const SizedBox(height: 16),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saveTransaction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryTypeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save Transaction',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab(String type, String label, Color activeColor) {
    final isSelected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _type = type;
          _selectedCategoryId = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
