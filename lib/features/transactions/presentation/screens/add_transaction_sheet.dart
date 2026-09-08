import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/services/app_review_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sliding_pill_control.dart';
import '../../../../core/widgets/sonner_toast.dart';
import '../../../../core/widgets/spring_shake.dart';
import '../../../accounts/data/account_repository.dart';
import '../../../categories/data/category_repository.dart';
import '../../data/transaction_repository.dart';
import '../widgets/num_keypad.dart';
import '../widgets/receipt_attachment_widget.dart';

class _SplitItemInput {
  String? categoryId;
  final TextEditingController amountController;
  final TextEditingController noteController;

  _SplitItemInput({
    this.categoryId,
    double initialAmount = 0.0,
    String initialNote = '',
  })  : amountController = TextEditingController(text: initialAmount > 0 ? initialAmount.toStringAsFixed(2) : ''),
        noteController = TextEditingController(text: initialNote);

  double get amount => double.tryParse(amountController.text.trim()) ?? 0.0;

  void dispose() {
    amountController.dispose();
    noteController.dispose();
  }
}

class AddTransactionSheet extends ConsumerStatefulWidget {
  final String initialType; // 'expense', 'income', 'transfer'
  /// When provided, the sheet opens in edit mode pre-filled with this transaction
  final Transaction? transactionToEdit;
  final List<TransactionSplitWithCategory>? initialSplits;
  final bool autoOpenScanner;

  const AddTransactionSheet({
    super.key,
    this.initialType = 'expense',
    this.transactionToEdit,
    this.initialSplits,
    this.autoOpenScanner = false,
  });

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final GlobalKey<SpringShakeState> _shakeKey = GlobalKey<SpringShakeState>();
  late String _type;
  String _amountStr = '0';
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _tagInputController = TextEditingController();
  final List<String> _tags = [];
  bool _isAddingTag = false;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  String? _selectedToAccountId;
  DateTime _selectedDate = DateTime.now();
  String? _receiptPath;

  // Split Transaction Support
  bool _isSplitMode = false;
  final List<_SplitItemInput> _splitItems = [];

  bool get _isEditMode => widget.transactionToEdit != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transactionToEdit;
    if (tx != null) {
      // Edit mode — pre-populate all fields
      _type = tx.type;
      _amountStr = tx.amount % 1 == 0 ? tx.amount.toInt().toString() : tx.amount.toStringAsFixed(2);
      _titleController.text = tx.title;
      _noteController.text = tx.note ?? '';
      _selectedCategoryId = tx.categoryId;
      _selectedAccountId = tx.accountId;
      _selectedToAccountId = tx.toAccountId;
      _selectedDate = tx.date;
      _receiptPath = tx.receiptPath;

      if (tx.tags != null && tx.tags!.trim().isNotEmpty) {
        _tags.addAll(
          tx.tags!.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty),
        );
      }

      if (tx.isSplit && tx.type == 'expense') {
        _isSplitMode = true;
        if (widget.initialSplits != null && widget.initialSplits!.isNotEmpty) {
          for (final s in widget.initialSplits!) {
            _splitItems.add(_SplitItemInput(
              categoryId: s.split.categoryId,
              initialAmount: s.split.amount,
              initialNote: s.split.note ?? '',
            ));
          }
        } else {
          // Fetch splits asynchronously if not passed directly
          Future.microtask(() async {
            final splits = await ref.read(transactionRepositoryProvider).getSplitsForTransaction(tx.id);
            if (mounted && splits.isNotEmpty) {
              setState(() {
                _splitItems.clear();
                for (final s in splits) {
                  _splitItems.add(_SplitItemInput(
                    categoryId: s.split.categoryId,
                    initialAmount: s.split.amount,
                    initialNote: s.split.note ?? '',
                  ));
                }
              });
            }
          });
        }
      }
    } else {
      _type = widget.initialType;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _tagInputController.dispose();
    for (final item in _splitItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _addTag(String raw) {
    var cleaned = raw.trim();
    if (cleaned.isEmpty) return;
    if (!cleaned.startsWith('#')) {
      cleaned = '#$cleaned';
    }
    cleaned = cleaned.replaceAll(RegExp(r'[^#a-zA-Z0-9_\-]'), '');
    if (cleaned.length <= 1) return;
    if (!_tags.contains(cleaned)) {
      setState(() {
        _tags.add(cleaned);
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  void _onKeypadPress(String val) {
    if (val != '.') {
      final digitCount = _amountStr == '0' ? 0 : _amountStr.replaceAll('.', '').length;
      if (digitCount >= 15) {
        return; // Max 15 numbers can be inserted
      }
    }
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

  void _toggleSplitMode(bool enabled, List<Category> categories) {
    setState(() {
      _isSplitMode = enabled;
      if (_isSplitMode && _splitItems.isEmpty) {
        final defaultCat1 = _selectedCategoryId ?? (categories.isNotEmpty ? categories.first.id : null);
        final defaultCat2 = categories.length > 1 ? categories[1].id : defaultCat1;
        final totalAmount = double.tryParse(_amountStr) ?? 0.0;
        final half = (totalAmount / 2).toStringAsFixed(2);
        final halfVal = double.tryParse(half) ?? 0.0;

        _splitItems.add(_SplitItemInput(categoryId: defaultCat1, initialAmount: halfVal));
        _splitItems.add(_SplitItemInput(categoryId: defaultCat2, initialAmount: (totalAmount - halfVal).clamp(0.0, double.infinity)));
      }
    });
  }

  void _addSplitItem(List<Category> categories) {
    final remaining = _getRemainingSplitAmount();
    final defaultCat = categories.isNotEmpty ? categories.first.id : null;
    setState(() {
      _splitItems.add(_SplitItemInput(
        categoryId: defaultCat,
        initialAmount: remaining > 0 ? remaining : 0.0,
      ));
    });
  }

  void _removeSplitItem(int index) {
    if (_splitItems.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A split transaction requires at least 2 category items')),
      );
      return;
    }
    setState(() {
      _splitItems[index].dispose();
      _splitItems.removeAt(index);
    });
  }

  double _getAllocatedSplitSum() {
    return _splitItems.fold<double>(0.0, (sum, item) => sum + item.amount);
  }

  double _getRemainingSplitAmount() {
    final total = double.tryParse(_amountStr) ?? 0.0;
    return total - _getAllocatedSplitSum();
  }

  void _attemptAutoMatchCategory(String keyword, List<Category>? categories) {
    if (categories == null || categories.isEmpty) return;
    final lowerKeyword = keyword.toLowerCase();
    for (final cat in categories) {
      final lowerCat = cat.name.toLowerCase();
      if (lowerCat.contains(lowerKeyword) || lowerKeyword.contains(lowerCat)) {
        _selectedCategoryId = cat.id;
        break;
      }
    }
  }

  void _autoFillRemainingToLastItem() {
    if (_splitItems.isEmpty) return;
    final total = double.tryParse(_amountStr) ?? 0.0;
    double currentOthers = 0;
    for (int i = 0; i < _splitItems.length - 1; i++) {
      currentOthers += _splitItems[i].amount;
    }
    final remaining = (total - currentOthers).clamp(0.0, double.infinity);
    setState(() {
      _splitItems.last.amountController.text = remaining.toStringAsFixed(2);
    });
  }

  void _changeType(String val) {
    if (_type == val) return;
    setState(() {
      _type = val;
      _selectedCategoryId = null;
      if (_type != 'expense') {
        _isSplitMode = false;
      }
    });
  }

  void _switchToNextType() {
    const types = ['expense', 'income', 'transfer'];
    final currentIndex = types.indexOf(_type);
    if (currentIndex < types.length - 1) {
      HapticFeedback.selectionClick();
      _changeType(types[currentIndex + 1]);
    }
  }

  void _switchToPreviousType() {
    const types = ['expense', 'income', 'transfer'];
    final currentIndex = types.indexOf(_type);
    if (currentIndex > 0) {
      HapticFeedback.selectionClick();
      _changeType(types[currentIndex - 1]);
    }
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity;
    if (velocity == null) return;
    // Swipe left (negative velocity) -> Next tab (Expense -> Income -> Transfer)
    if (velocity < -150) {
      _switchToNextType();
    }
    // Swipe right (positive velocity) -> Previous tab (Transfer -> Income -> Expense)
    else if (velocity > 150) {
      _switchToPreviousType();
    }
  }

  Future<void> _saveTransaction() async {
    final amount = double.tryParse(_amountStr) ?? 0.0;
    if (amount <= 0) {
      _shakeKey.currentState?.shake();
      Sonner.error('Invalid Amount', description: 'Please enter an amount greater than 0');
      return;
    }

    if (_selectedAccountId == null) {
      _shakeKey.currentState?.shake();
      Sonner.error('Account Required', description: 'Please select an account');
      return;
    }

    if (_type == 'transfer' && _selectedToAccountId == null) {
      _shakeKey.currentState?.shake();
      Sonner.error('Destination Required', description: 'Please select destination account for transfer');
      return;
    }

    if (_type == 'transfer' && _selectedAccountId == _selectedToAccountId) {
      _shakeKey.currentState?.shake();
      Sonner.error('Identical Accounts', description: 'Source and destination accounts must be different');
      return;
    }

    // Split Validation
    if (_isSplitMode && _type == 'expense') {
      if (_splitItems.length < 2) {
        _shakeKey.currentState?.shake();
        Sonner.error('Split Validation', description: 'Please add at least 2 split category items');
        return;
      }

      for (int i = 0; i < _splitItems.length; i++) {
        final item = _splitItems[i];
        if (item.categoryId == null) {
          Sonner.error('Category Required', description: 'Please select a category for item #${i + 1}');
          return;
        }
        if (item.amount <= 0) {
          Sonner.error('Invalid Split Amount', description: 'Item #${i + 1} must have an amount greater than 0');
          return;
        }
      }

      final allocatedSum = _getAllocatedSplitSum();
      if ((allocatedSum - amount).abs() > 0.01) {
        _shakeKey.currentState?.shake();
        Sonner.error(
          'Split Mismatch',
          description: 'Allocated sum (${CurrencyFormatter.format(allocatedSum)}) does not match total (${CurrencyFormatter.format(amount)})',
        );
        return;
      }
    }

    String title = _titleController.text.trim();
    if (title.isEmpty) {
      if (_type == 'transfer') {
        title = 'Account Transfer';
      } else if (_isSplitMode) {
        title = 'Split Expense (${_splitItems.length} items)';
      } else {
        title = _type == 'expense' ? 'Expense' : 'Income';
      }
    }
    if (title.length > 100) {
      title = title.substring(0, 100);
    }

    // Extract tags from chips + auto-detect from note & title
    final allTagsSet = <String>{..._tags};
    final hashtagRegex = RegExp(r'#([a-zA-Z0-9_\-]+)');
    for (final match in hashtagRegex.allMatches('${_noteController.text} ${_titleController.text}')) {
      final tag = match.group(0);
      if (tag != null && tag.length > 1) {
        allTagsSet.add(tag);
      }
    }
    final tagsString = allTagsSet.isNotEmpty ? allTagsSet.join(',') : null;

    if (_isEditMode) {
      // --- UPDATE existing transaction ---
      final existing = widget.transactionToEdit!;
      final companion = TransactionsCompanion(
        id: drift.Value(existing.id),
        title: drift.Value(title),
        amount: drift.Value(amount),
        type: drift.Value(_type),
        categoryId: drift.Value(_isSplitMode ? null : _selectedCategoryId),
        accountId: drift.Value(_selectedAccountId!),
        toAccountId: drift.Value(_selectedToAccountId),
        date: drift.Value(_selectedDate),
        note: drift.Value(_noteController.text.trim().isEmpty ? null : _noteController.text.trim()),
        tags: drift.Value(tagsString),
        receiptPath: drift.Value(_receiptPath),
        isSplit: drift.Value(_isSplitMode && _type == 'expense'),
        createdAt: drift.Value(existing.createdAt),
      );

      if (_isSplitMode && _type == 'expense') {
        const uuid = Uuid();
        final splitsCompanions = _splitItems.map((item) {
          return TransactionSplitsCompanion.insert(
            id: uuid.v4(),
            transactionId: existing.id,
            categoryId: item.categoryId!,
            amount: item.amount,
            note: drift.Value(item.noteController.text.trim().isEmpty ? null : item.noteController.text.trim()),
          );
        }).toList();

        await ref.read(transactionRepositoryProvider).updateTransactionWithSplits(companion, splitsCompanions);
      } else {
        if (existing.isSplit) {
          await ref.read(transactionRepositoryProvider).updateTransactionWithSplits(companion, []);
        } else {
          await ref.read(transactionRepositoryProvider).updateTransaction(companion);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        Sonner.success(
          'Updated "$title"',
          description: CurrencyFormatter.format(amount),
        );
      }
      return;
    }

    // --- CREATE new transaction ---
    const uuid = Uuid();
    final txId = uuid.v4();

    final txCompanion = TransactionsCompanion.insert(
      id: txId,
      title: title,
      amount: amount,
      type: _type,
      categoryId: drift.Value(_isSplitMode ? null : _selectedCategoryId),
      accountId: _selectedAccountId!,
      toAccountId: drift.Value(_selectedToAccountId),
      date: drift.Value(_selectedDate),
      note: drift.Value(_noteController.text.trim().isEmpty ? null : _noteController.text.trim()),
      tags: drift.Value(tagsString),
      receiptPath: drift.Value(_receiptPath),
      isSplit: drift.Value(_isSplitMode && _type == 'expense'),
    );

    if (_isSplitMode && _type == 'expense') {
      final splitsCompanions = _splitItems.map((item) {
        return TransactionSplitsCompanion.insert(
          id: uuid.v4(),
          transactionId: txId,
          categoryId: item.categoryId!,
          amount: item.amount,
          note: drift.Value(item.noteController.text.trim().isEmpty ? null : item.noteController.text.trim()),
        );
      }).toList();

      await ref.read(transactionRepositoryProvider).createTransactionWithSplits(txCompanion, splitsCompanions);
    } else {
      await ref.read(transactionRepositoryProvider).createTransaction(txCompanion);
    }
    ref.read(appReviewServiceProvider).recordTransactionLogged();

    if (mounted) {
      Navigator.pop(context);
      Sonner.success(
        'Saved "$title"',
        description: CurrencyFormatter.format(amount),
      );
    }
  }


  String _formatCompactDate(DateTime date) {
    final now = DateTime.now();
    if (now.year == date.year && now.month == date.month && now.day == date.day) {
      return 'Today, ${DateFormat('MMM d').format(date)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == date.year && yesterday.month == date.month && yesterday.day == date.day) {
      return 'Yesterday';
    }
    return DateFormat('MMM d, yyyy').format(date);
  }

  Widget _buildDatePickerWidget(bool isDark, {String label = 'Date'}) {
    return InkWell(
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
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _formatCompactDate(_selectedDate),
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 24, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteAndTagsSection(bool isDark) {
    final suggestedTags = _type == 'expense'
        ? const ['#dining', '#groceries', '#bills', '#shopping', '#travel', '#health', '#personal', '#entertainment']
        : (_type == 'income'
            ? const ['#salary', '#freelance', '#investment', '#gift', '#bonus']
            : const ['#savings', '#bills', '#investment', '#transfer']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Note / Remarks input
        TextField(
          controller: _noteController,
          maxLength: 150,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          buildCounter: (_, {required currentLength, required isFocused, required maxLength}) => null,
          decoration: InputDecoration(
            labelText: 'Note & Remarks',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintText: 'Add note (e.g. #dinner, lunch)...',
            prefixIcon: const Icon(Icons.sticky_note_2_outlined, size: 20),
            filled: true,
            fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13.5),
        ),

        const SizedBox(height: 6),

        // Tags & Hashtag Chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ..._tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tag.startsWith('#') ? tag : '#$tag',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _removeTag(tag),
                        child: const Icon(Icons.close_rounded, size: 13, color: AppColors.primary),
                      ),
                    ],
                  ),
                )),
            if (_isAddingTag)
              Container(
                width: 120,
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagInputController,
                        autofocus: true,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          prefixText: '#',
                          prefixStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                          hintText: 'tag',
                          hintStyle: TextStyle(fontSize: 11),
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (val) {
                          _addTag(val);
                          _tagInputController.clear();
                          setState(() => _isAddingTag = false);
                        },
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (_tagInputController.text.trim().isNotEmpty) {
                          _addTag(_tagInputController.text);
                          _tagInputController.clear();
                        }
                        setState(() => _isAddingTag = false);
                      },
                      child: const Icon(Icons.check_rounded, size: 15, color: AppColors.primary),
                    ),
                    const SizedBox(width: 2),
                    GestureDetector(
                      onTap: () {
                        _tagInputController.clear();
                        setState(() => _isAddingTag = false);
                      },
                      child: const Icon(Icons.close_rounded, size: 14, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              InkWell(
                onTap: () => setState(() => _isAddingTag = true),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 13, color: isDark ? Colors.white60 : Colors.black54),
                      const SizedBox(width: 3),
                      Text(
                        'Add #tag',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Quick suggestion chips
            if (_tags.length < 3)
              ...suggestedTags
                  .where((t) => !_tags.contains(t))
                  .take(3)
                  .map((tag) => InkWell(
                        onTap: () => _addTag(tag),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currencyProvider);
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

    final totalAmount = double.tryParse(_amountStr) ?? 0.0;
    final allocatedSum = _isSplitMode ? _getAllocatedSplitSum() : totalAmount;
    final remainingSplit = _isSplitMode ? totalAmount - allocatedSum : 0.0;
    final isSplitMatched = (remainingSplit.abs() <= 0.01);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardInset > 0;

    // Auto-select first category if none selected
    categoriesAsync.whenData((categories) {
      if (_selectedCategoryId == null && categories.isNotEmpty && !_isSplitMode && widget.transactionToEdit == null) {
        _selectedCategoryId = categories.first.id;
      }
    });

    return SafeArea(
      top: false,
      bottom: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header handle + Type Switcher Tabs + Amount Display (Swipeable)
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: _handleHorizontalSwipe,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header handle
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Type Switcher Tabs (Fluid Sliding Pill with drag & swipe)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SlidingPillControl<String>(
                        selectedValue: _type,
                        onValueChanged: _changeType,
                        segments: const [
                          SlidingPillSegment(
                            value: 'expense',
                            label: 'Expense',
                            activeColor: AppColors.expense,
                          ),
                          SlidingPillSegment(
                            value: 'income',
                            label: 'Income',
                            activeColor: AppColors.income,
                          ),
                          SlidingPillSegment(
                            value: 'transfer',
                            label: 'Transfer',
                            activeColor: AppColors.transfer,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Amount Display Area with Emil Kowalski Decaying Spring Shake
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SpringShake(
                        key: _shakeKey,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          decoration: BoxDecoration(
                            color: primaryTypeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: primaryTypeColor.withValues(alpha: 0.3), width: 1.5),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${CurrencyFormatter.activeCurrencySymbol} ',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: primaryTypeColor,
                                  ),
                                ),
                                Text(
                                  _amountStr,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: primaryTypeColor,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Middle Scrollable Form Content (Smooth scroll with auto-fit, swipeable)
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: _handleHorizontalSwipe,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title / Description
                        TextField(
                          controller: _titleController,
                          maxLength: 100,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          buildCounter: (context, {required currentLength, required isFocused, required maxLength}) {
                            if (currentLength > 60) {
                              return Text(
                                '$currentLength/$maxLength',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: currentLength >= 95 ? AppColors.expense : Colors.grey,
                                ),
                              );
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: _type == 'transfer'
                                ? 'Transfer Note (Optional)'
                                : (_isSplitMode ? 'Merchant / Split Title' : 'Title / Merchant Name'),
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            hintText: _type == 'transfer'
                                ? 'Add note...'
                                : 'e.g. Grocery, Coffee, Store...',
                            prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                            filled: true,
                            fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13.5),
                        ),

                      const SizedBox(height: 8),

                      // Receipt / Bill Attachment & Scanner (Compact 40px pill / 42px badge)
                      ReceiptAttachmentWidget(
                        autoOpenScanner: widget.autoOpenScanner,
                        receiptPath: _receiptPath,
                        transactionTitle: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null,
                        onReceiptChanged: (newPath) {
                          setState(() => _receiptPath = newPath);
                        },
                        onReceiptScanned: (data, savedPath) {
                          setState(() {
                            _receiptPath = savedPath;
                            if (data.amount != null && data.amount! > 0) {
                              _amountStr = data.amount! % 1 == 0
                                  ? data.amount!.toInt().toString()
                                  : data.amount!.toStringAsFixed(2);
                            }
                            if (data.date != null) {
                              _selectedDate = data.date!;
                            }
                            if (data.merchantName != null && data.merchantName!.isNotEmpty) {
                              if (_titleController.text.trim().isEmpty) {
                                final name = data.merchantName!;
                                _titleController.text = name.length > 100 ? name.substring(0, 100) : name;
                              }
                            }
                            if (data.suggestedCategoryKeyword != null && _selectedCategoryId == null) {
                              _attemptAutoMatchCategory(data.suggestedCategoryKeyword!, categoriesAsync.valueOrNull);
                            }
                          });
                        },
                      ),

                      const SizedBox(height: 8),

                      // Account & Date Row (Side-by-Side 50/50 layout)
                      if (_type == 'transfer') ...[
                        Row(
                          children: [
                            Expanded(
                              child: accountsAsync.when(
                                data: (accounts) {
                                  return DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: _selectedAccountId,
                                    decoration: InputDecoration(
                                      labelText: 'From Account',
                                      filled: true,
                                      fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      isDense: true,
                                    ),
                                    items: accounts.map((acc) {
                                      return DropdownMenuItem(
                                        value: acc.id,
                                        child: Row(
                                          children: [
                                            Icon(IconHelper.getIcon(acc.icon), size: 16, color: Color(acc.color)),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                acc.name,
                                                style: const TextStyle(fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: accountsAsync.when(
                                data: (accounts) {
                                  return DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: _selectedToAccountId,
                                    decoration: InputDecoration(
                                      labelText: 'To Account',
                                      filled: true,
                                      fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      isDense: true,
                                    ),
                                    items: accounts.map((acc) {
                                      return DropdownMenuItem(
                                        value: acc.id,
                                        child: Row(
                                          children: [
                                            Icon(IconHelper.getIcon(acc.icon), size: 16, color: Color(acc.color)),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                acc.name,
                                                style: const TextStyle(fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
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
                        ),
                        const SizedBox(height: 8),
                        _buildDatePickerWidget(isDark),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: accountsAsync.when(
                                data: (accounts) {
                                  return DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: _selectedAccountId,
                                    decoration: InputDecoration(
                                      labelText: 'Account',
                                      filled: true,
                                      fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      isDense: true,
                                    ),
                                    items: accounts.map((acc) {
                                      return DropdownMenuItem(
                                        value: acc.id,
                                        child: Row(
                                          children: [
                                            Icon(IconHelper.getIcon(acc.icon), size: 16, color: Color(acc.color)),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                acc.name,
                                                style: const TextStyle(fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildDatePickerWidget(isDark),
                            ),
                          ],
                        ),
                      ],

                      // Category Dropdown & Split Mode Toggle
                      if (_type == 'expense') ...[
                        const SizedBox(height: 8),
                        categoriesAsync.when(
                          data: (categories) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!_isSplitMode) ...[
                                  // Category Dropdown + Split Action Pill
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          initialValue: _selectedCategoryId,
                                          decoration: InputDecoration(
                                            labelText: 'Category',
                                            filled: true,
                                            fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            isDense: true,
                                          ),
                                          items: categories.map((cat) {
                                            return DropdownMenuItem(
                                              value: cat.id,
                                              child: Row(
                                                children: [
                                                  Icon(IconHelper.getIcon(cat.icon), size: 16, color: Color(cat.color)),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      cat.name,
                                                      style: const TextStyle(fontSize: 12.5),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) => setState(() => _selectedCategoryId = val),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Material(
                                        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                        borderRadius: BorderRadius.circular(14),
                                        child: InkWell(
                                          onTap: () => _toggleSplitMode(true, categories),
                                          borderRadius: BorderRadius.circular(14),
                                          child: Container(
                                            height: 48,
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.call_split_rounded, size: 16, color: Colors.grey),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Split',
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  // Split Header Row with Active Split Indicator & Switch to cancel
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.call_split_rounded, size: 16, color: AppColors.primary),
                                          SizedBox(width: 6),
                                          Text(
                                            'Split Categories',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                                          ),
                                        ],
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _toggleSplitMode(false, categories),
                                        icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                                        label: const Text('Cancel Split', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  // Split Items List
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSplitMatched ? AppColors.income : AppColors.warning,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Allocated: ${CurrencyFormatter.format(allocatedSum)} / ${CurrencyFormatter.format(totalAmount)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: isSplitMatched ? AppColors.income : AppColors.warning,
                                              ),
                                            ),
                                            if (!isSplitMatched)
                                              InkWell(
                                                onTap: _autoFillRemainingToLastItem,
                                                child: Text(
                                                  'Auto-fill (${CurrencyFormatter.format(remainingSplit)})',
                                                  style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700),
                                                ),
                                              )
                                            else
                                              const Row(
                                                children: [
                                                  Icon(Icons.check_circle_rounded, color: AppColors.income, size: 14),
                                                  SizedBox(width: 4),
                                                  Text('Balanced', style: TextStyle(fontSize: 11, color: AppColors.income, fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: _splitItems.length,
                                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                                          itemBuilder: (context, index) {
                                            final item = _splitItems[index];
                                            return Row(
                                              children: [
                                                Expanded(
                                                  flex: 3,
                                                  child: DropdownButtonFormField<String>(
                                                    initialValue: item.categoryId,
                                                    isDense: true,
                                                    decoration: InputDecoration(
                                                      filled: true,
                                                      fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                    ),
                                                    items: categories.map((cat) {
                                                      return DropdownMenuItem(
                                                        value: cat.id,
                                                        child: Row(
                                                          children: [
                                                            Icon(IconHelper.getIcon(cat.icon), size: 14, color: Color(cat.color)),
                                                            const SizedBox(width: 6),
                                                            Expanded(
                                                              child: Text(cat.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }).toList(),
                                                    onChanged: (val) => setState(() => item.categoryId = val),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  flex: 2,
                                                  child: TextField(
                                                    controller: item.amountController,
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    onChanged: (_) => setState(() {}),
                                                    decoration: InputDecoration(
                                                      hintText: 'Amount',
                                                      prefixText: '${CurrencyFormatter.activeCurrencySymbol} ',
                                                      filled: true,
                                                      fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                    ),
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 18),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  onPressed: () => _removeSplitItem(index),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        TextButton.icon(
                                          onPressed: () => _addSplitItem(categories),
                                          icon: const Icon(Icons.add_rounded, size: 16),
                                          label: const Text('+ Add Category Item', style: TextStyle(fontSize: 12)),
                                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                      ] else if (_type == 'income') ...[
                        // Income Category Dropdown
                        const SizedBox(height: 8),
                        categoriesAsync.when(
                          data: (categories) {
                            return DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _selectedCategoryId,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                filled: true,
                                fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                isDense: true,
                              ),
                              items: categories.map((cat) {
                                return DropdownMenuItem(
                                  value: cat.id,
                                  child: Row(
                                    children: [
                                      Icon(IconHelper.getIcon(cat.icon), size: 16, color: Color(cat.color)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          cat.name,
                                          style: const TextStyle(fontSize: 12.5),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedCategoryId = val),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                      ],
                      _buildNoteAndTagsSection(isDark),
                    ],
                  ),
                ),
              ),
            ),

              // Docked Bottom Action & Keypad Area (Permanently accessible without scrolling)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  border: Border(
                    top: BorderSide(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  6,
                  16,
                  isKeyboardOpen ? 8 : 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isKeyboardOpen && !_isSplitMode) ...[
                      NumKeypad(
                        accentColor: primaryTypeColor,
                        onKeyPressed: _onKeypadPress,
                        onDelete: _onKeypadDelete,
                        onClear: _onKeypadClear,
                      ),
                      const SizedBox(height: 6),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saveTransaction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTypeColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(
                          _isEditMode
                              ? 'Update Transaction'
                              : (_isSplitMode ? 'Save Split Transaction' : 'Save Transaction'),
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
