import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/providers/privacy_mask_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../accounts/data/account_repository.dart';
import '../../../transactions/data/transaction_repository.dart';

class TotalBalanceCard extends ConsumerWidget {
  const TotalBalanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currencyProvider);
    final isMasked = ref.watch(privacyMaskProvider);
    final themeState = ref.watch(themeStateProvider);
    final palette = themeState.palette;
    final isAmoled = themeState.mode == AppThemeMode.amoled;
    final accountsAsync = ref.watch(accountsWithBalancesStreamProvider);
    final summaryAsync = ref.watch(currentMonthSummaryStreamProvider);

    final gradStart = isAmoled
        ? const Color(0xFF181818)
        : (Color.lerp(palette.primary, const Color(0xFF0A0F1D), 0.45) ?? palette.primary);
    final gradMid = isAmoled
        ? const Color(0xFF222222)
        : (Color.lerp(palette.primary, palette.secondary, 0.35) ?? palette.primary);
    final gradEnd = isAmoled
        ? const Color(0xFF2C2C2C)
        : (Color.lerp(palette.primary, Colors.black, 0.1) ?? palette.primary);

    final totalNetWorth = accountsAsync.when(
      data: (accounts) => accounts.fold<double>(0.0, (sum, a) => sum + a.currentBalance),
      loading: () => 0.0,
      error: (_, _) => 0.0,
    );

    return InkWell(
      onLongPress: () => ref.read(privacyMaskProvider.notifier).toggle(),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [gradStart, gradMid, gradEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: palette.primary.withValues(alpha: isAmoled ? 0.05 : 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Total Net Worth',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMasked ? Icons.visibility_off_outlined : Icons.shield_outlined,
                        color: isMasked ? Colors.amberAccent : Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMasked ? 'Privacy Mask' : '100% Offline',
                        style: TextStyle(
                          color: isMasked ? Colors.amberAccent : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                CurrencyFormatter.format(totalNetWorth, mask: isMasked),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: summaryAsync.when(
                data: (summary) => Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.income.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_downward_rounded, color: Colors.greenAccent, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Income', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                Text(
                                  CurrencyFormatter.format(summary.totalIncome, mask: isMasked),
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 28, width: 1, color: Colors.white24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.expense.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_upward_rounded, color: Colors.redAccent, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Expenses', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                Text(
                                  CurrencyFormatter.format(summary.totalExpense, mask: isMasked),
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                  ),
                ),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
