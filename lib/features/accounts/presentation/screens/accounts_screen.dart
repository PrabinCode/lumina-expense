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
    final nameController = TextEditingController(text: accountToEdit?.name ?? '');
    final balanceController = TextEditingController(
      text: accountToEdit != null ? accountToEdit.initialBalance.toStringAsFixed(2) : '0.00',
    );
    String type = accountToEdit?.type ?? 'bank';
    String currency = accountToEdit?.currency ?? ref.read(currencyProvider).code;
    String icon = accountToEdit?.icon ?? 'account_balance';
    int color = accountToEdit?.color ?? 0xFF2196F3;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                accountToEdit == null ? 'Add Account / Wallet' : 'Edit Account',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Account Name',
                        hintText: 'e.g. Chase Bank, Cash Wallet',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Account Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash Wallet')),
                        DropdownMenuItem(value: 'bank', child: Text('Bank Account')),
                        DropdownMenuItem(value: 'creditCard', child: Text('Credit Card')),
                        DropdownMenuItem(value: 'savings', child: Text('Savings / Investment')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            type = val;
                            if (val == 'cash') {
                              icon = 'payments';
                              color = 0xFF4CAF50;
                            } else if (val == 'bank') {
                              icon = 'account_balance';
                              color = 0xFF2196F3;
                            } else if (val == 'creditCard') {
                              icon = 'credit_card';
                              color = 0xFF9C27B0;
                            } else {
                              icon = 'savings';
                              color = 0xFFFF9800;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: balanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: accountToEdit == null ? 'Initial Starting Balance' : 'Base Initial Balance',
                        prefixText: '${CurrencyFormatter.activeCurrencySymbol} ',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final balance = double.tryParse(balanceController.text.trim()) ?? 0.0;
                    if (name.isEmpty) return;

                    final repo = ref.read(accountRepositoryProvider);

                    if (accountToEdit == null) {
                      const uuid = Uuid();
                      await repo.createAccount(
                        AccountsCompanion.insert(
                          id: uuid.v4(),
                          name: name,
                          type: type,
                          initialBalance: drift.Value(balance),
                          currency: drift.Value(currency),
                          icon: drift.Value(icon),
                          color: drift.Value(color),
                        ),
                      );
                    } else {
                      await repo.updateAccount(
                        AccountsCompanion(
                          id: drift.Value(accountToEdit.id),
                          name: drift.Value(name),
                          type: drift.Value(type),
                          initialBalance: drift.Value(balance),
                          currency: drift.Value(currency),
                          icon: drift.Value(icon),
                          color: drift.Value(color),
                          isArchived: drift.Value(accountToEdit.isArchived),
                          createdAt: drift.Value(accountToEdit.createdAt),
                        ),
                      );
                    }

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(accountToEdit == null ? 'Save Account' : 'Update Account'),
                ),
              ],
            );
          },
        );
      },
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
                await ref.read(accountRepositoryProvider).deleteAccount(account.id);
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
  Widget build(BuildContext context, WidgetRef ref) {
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
