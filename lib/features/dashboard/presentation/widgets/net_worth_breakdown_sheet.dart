import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/currency_provider.dart';
import '../../../../core/providers/privacy_mask_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/rolling_ticker.dart';
import '../../../accounts/data/account_repository.dart';
import '../../../accounts/presentation/screens/accounts_screen.dart';

class NetWorthBreakdownSheet extends ConsumerWidget {
  const NetWorthBreakdownSheet({super.key});

  static Future<void> show(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const NetWorthBreakdownSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currencyProvider);
    final isMasked = ref.watch(privacyMaskProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statsAsync = ref.watch(accountsFinancialStatsStreamProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return statsAsync.when(
          data: (stats) {
            final totalNetWorth = stats.fold<double>(0.0, (s, a) => s + (a.currentBalance > 0 ? a.currentBalance : 0.0));
            final totalMonthIncome = stats.fold<double>(0.0, (s, a) => s + a.monthIncome);
            final totalMonthExpense = stats.fold<double>(0.0, (s, a) => s + a.monthExpense);

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
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
                  const SizedBox(height: 14),

                  // Header Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Net Worth & Wallet Breakdown',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              '${stats.length} active account${stats.length > 1 ? "s" : ""} • Real-time balances',
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
                  const SizedBox(height: 16),

                  // Hero Balance Summary Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL LIQUID NET WORTH',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: RollingTicker(
                            text: CurrencyFormatter.format(totalNetWorth, mask: isMasked),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.income.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_downward_rounded, size: 12, color: AppColors.income),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Inflow: ${CurrencyFormatter.format(totalMonthIncome, mask: isMasked)}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.income,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.expense.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_upward_rounded, size: 12, color: AppColors.expense),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Outflow: ${CurrencyFormatter.format(totalMonthExpense, mask: isMasked)}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.expense,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Multi-Segment Allocation Bar
                  if (totalNetWorth > 0 && stats.isNotEmpty) ...[
                    const Text(
                      'Wealth Allocation Distribution',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 10,
                        width: double.infinity,
                        child: Row(
                          children: stats.map((stat) {
                            if (stat.shareOfNetWorth <= 0) return const SizedBox.shrink();
                            return Expanded(
                              flex: (stat.shareOfNetWorth * 10).toInt().clamp(1, 1000),
                              child: Container(
                                color: Color(stat.account.color),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Allocation Legend Wrap
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: stats.where((s) => s.shareOfNetWorth > 0).take(4).map((stat) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Color(stat.account.color),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${stat.account.name}: ${stat.shareOfNetWorth.toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Accounts List Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Accounts & Wallets',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AccountsScreen()),
                          );
                        },
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.settings_outlined, size: 14),
                        label: const Text('Manage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Scrollable Accounts Breakdown List
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: stats.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = stats[index];
                        final acc = item.account;
                        final accColor = Color(acc.color);
                        final netFlow = item.monthIncome - item.monthExpense;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: accColor.withValues(alpha: 0.15),
                                    child: Icon(IconHelper.getIcon(acc.icon), color: accColor, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                acc.name,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: accColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                acc.type.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: accColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.shareOfNetWorth > 0
                                              ? '${item.shareOfNetWorth.toStringAsFixed(1)}% of total net worth'
                                              : '0% share',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyFormatter.format(item.currentBalance, mask: isMasked),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: item.currentBalance >= 0 ? null : AppColors.expense,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Current Balance',
                                        style: TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),
                              Divider(height: 1, thickness: 0.8, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              const SizedBox(height: 8),

                              // Month Activity Strip
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildMicroMetric(
                                    'This Month In',
                                    CurrencyFormatter.format(item.monthIncome, mask: isMasked),
                                    item.monthIncome > 0 ? AppColors.income : Colors.grey,
                                  ),
                                  _buildMicroMetric(
                                    'This Month Spent',
                                    CurrencyFormatter.format(item.monthExpense, mask: isMasked),
                                    item.monthExpense > 0 ? AppColors.expense : Colors.grey,
                                  ),
                                  _buildMicroMetric(
                                    'Net Flow',
                                    (netFlow >= 0 ? '+' : '') + CurrencyFormatter.format(netFlow, mask: isMasked),
                                    netFlow >= 0 ? AppColors.income : AppColors.expense,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading account breakdown: $e')),
        );
      },
    );
  }

  Widget _buildMicroMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
