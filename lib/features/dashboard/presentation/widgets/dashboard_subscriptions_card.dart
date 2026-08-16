import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../subscriptions/data/subscription_repository.dart';
import '../../../subscriptions/presentation/screens/subscriptions_screen.dart';

class DashboardSubscriptionsCard extends ConsumerWidget {
  const DashboardSubscriptionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(subscriptionsSummaryStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return summaryAsync.when(
      data: (summary) {
        if (summary.activeCount == 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionsScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.subscriptions_rounded, color: Color(0xFF3B82F6), size: 18),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Recurring Bills & Subs',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ],
                        ),
                        if (summary.upcomingThisWeekCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${summary.upcomingThisWeekCount} due soon',
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          )
                        else
                          Text(
                            '${summary.activeCount} Active',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${CurrencyFormatter.format(summary.totalMonthlyBurn)} / mo',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        Text(
                          'Annual: ${CurrencyFormatter.format(summary.totalYearlyBurn)}/yr',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
