import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../data/account_repository.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  void _showAddEditAccountDialog(BuildContext context, WidgetRef ref, {Account? accountToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddEditAccountSheet(accountToEdit: accountToEdit),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref, Account account, int totalAccounts) {
    if (totalAccounts <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the only remaining account.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete "${account.name}"?'),
          content: const Text(
            'Are you sure you want to delete this account? Any associated transactions will remain but may lose their account link.',
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
                final repo = ref.read(accountRepositoryProvider);
                await repo.deleteAccount(account.id);
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Deleted account "${account.name}"'),
                      duration: const Duration(seconds: 5),
                      action: SnackBarAction(
                        label: 'UNDO',
                        textColor: AppColors.income,
                        onPressed: () async {
                          await repo.restoreAccount(account);
                          messenger.clearSnackBars();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('✓ Restored account "${account.name}"'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),

          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currencyProvider);
    final accountsAsync = ref.watch(accountsWithBalancesStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts & Wallets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card_rounded),
            tooltip: 'Add Account',
            onPressed: () => _showAddEditAccountDialog(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            accountsAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) {
                  return const Center(child: Text('No accounts found'));
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: accounts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = accounts[index];
                    final acc = item.account;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color(acc.color).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(IconHelper.getIcon(acc.icon), color: Color(acc.color), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(
                                  acc.type.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.format(item.currentBalance),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              Text(
                                acc.currency,
                                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            onSelected: (action) {
                              if (action == 'edit') {
                                _showAddEditAccountDialog(context, ref, accountToEdit: acc);
                              } else if (action == 'delete') {
                                _confirmDeleteAccount(context, ref, acc, accounts.length);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit Account'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expense),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: AppColors.expense)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error loading accounts: $err'),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _AddEditAccountSheet extends ConsumerStatefulWidget {
  final Account? accountToEdit;
  const _AddEditAccountSheet({this.accountToEdit});

  @override
  ConsumerState<_AddEditAccountSheet> createState() => _AddEditAccountSheetState();
}

class _AddEditAccountSheetState extends ConsumerState<_AddEditAccountSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late String _type;
  late String _currency;
  late String _icon;
  late int _color;

  @override
  void initState() {
    super.initState();
    final edit = widget.accountToEdit;
    _nameController = TextEditingController(text: edit?.name ?? '');
    _balanceController = TextEditingController(
      text: edit != null ? edit.initialBalance.toStringAsFixed(2) : '0.00',
    );
    _type = edit?.type ?? 'bank';
    _currency = edit?.currency ?? ref.read(currencyProvider).code;
    _icon = edit?.icon ?? 'account_balance';
    _color = edit?.color ?? 0xFF2196F3;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.accountToEdit != null;

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Account' : 'Add Account / Wallet',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Account Name',
                        hintText: 'e.g. Chase Bank, Cash Wallet',
                        prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: InputDecoration(
                        labelText: 'Account Type',
                        prefixIcon: const Icon(Icons.category_outlined, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash Wallet')),
                        DropdownMenuItem(value: 'bank', child: Text('Bank Account')),
                        DropdownMenuItem(value: 'creditCard', child: Text('Credit Card')),
                        DropdownMenuItem(value: 'savings', child: Text('Savings / Investment')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _type = val;
                            if (val == 'cash') {
                              _icon = 'payments';
                              _color = 0xFF4CAF50;
                            } else if (val == 'bank') {
                              _icon = 'account_balance';
                              _color = 0xFF2196F3;
                            } else if (val == 'creditCard') {
                              _icon = 'credit_card';
                              _color = 0xFF9C27B0;
                            } else {
                              _icon = 'savings';
                              _color = 0xFFFF9800;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _balanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: isEditing ? 'Base Initial Balance' : 'Initial Starting Balance',
                        prefixText: '${CurrencyFormatter.activeCurrencySymbol} ',
                        prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = _nameController.text.trim();
                          final balance = double.tryParse(_balanceController.text.trim()) ?? 0.0;
                          if (name.isEmpty) return;

                          final repo = ref.read(accountRepositoryProvider);

                          if (widget.accountToEdit == null) {
                            const uuid = Uuid();
                            await repo.createAccount(
                              AccountsCompanion.insert(
                                id: uuid.v4(),
                                name: name,
                                type: _type,
                                initialBalance: drift.Value(balance),
                                currency: drift.Value(_currency),
                                icon: drift.Value(_icon),
                                color: drift.Value(_color),
                              ),
                            );
                          } else {
                            await repo.updateAccount(
                              AccountsCompanion(
                                id: drift.Value(widget.accountToEdit!.id),
                                name: drift.Value(name),
                                type: drift.Value(_type),
                                initialBalance: drift.Value(balance),
                                currency: drift.Value(_currency),
                                icon: drift.Value(_icon),
                                color: drift.Value(_color),
                                isArchived: drift.Value(widget.accountToEdit!.isArchived),
                                createdAt: drift.Value(widget.accountToEdit!.createdAt),
                              ),
                            );
                          }

                          if (context.mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          isEditing ? 'Update Account' : 'Save Account',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
