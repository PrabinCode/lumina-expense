import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../data/account_repository.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final balanceController = TextEditingController(text: '0.00');
    String type = 'bank';
    String currency = 'USD';
    String icon = 'account_balance';
    int color = 0xFF2196F3;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Account / Wallet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Account Name (e.g. Chase, Cash)', border: OutlineInputBorder()),
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
                      decoration: const InputDecoration(
                        labelText: 'Initial Starting Balance',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final balance = double.tryParse(balanceController.text.trim()) ?? 0.0;
                    if (name.isEmpty) return;

                    const uuid = Uuid();
                    await ref.read(accountRepositoryProvider).createAccount(
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
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save Account'),
                ),
              ],
            );
          },
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
            onPressed: () => _showAddAccountDialog(context, ref),
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
