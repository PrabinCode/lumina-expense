import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/models/analytics_models.dart';

class Macro503020Card extends StatelessWidget {
  final Macro503020Summary summary;

  const Macro503020Card({
    super.key,
    required this.summary,
  });


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final total = (summary.needsSpent + summary.wantsSpent + summary.savingsTransferred);
    final denom = total > 0 ? total : 1.0;
    final needsFlex = (summary.needsSpent / denom * 100).round();
    final wantsFlex = (summary.wantsSpent / denom * 100).round();
    final savingsFlex = (summary.savingsTransferred / denom * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.pie_chart_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '50/30/20 Macro Budget',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Financial Health',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3-Segment Segmented Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  if (needsFlex > 0)
                    Expanded(
                      flex: needsFlex,
                      child: Container(color: const Color(0xFF3B82F6)), // Blue for Needs
                    ),
                  if (wantsFlex > 0)
                    Expanded(
                      flex: wantsFlex,
                      child: Container(color: const Color(0xFFF59E0B)), // Amber for Wants
                    ),
                  if (savingsFlex > 0)
                    Expanded(
                      flex: savingsFlex,
                      child: Container(color: const Color(0xFF10B981)), // Emerald for Savings
                    ),
                  if (needsFlex == 0 && wantsFlex == 0 && savingsFlex == 0)
                    Expanded(child: Container(color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant)),
                ],
              ),
            ),
          ),


          const SizedBox(height: 16),

          // 3 Macro Bucket Details
          Row(
            children: [
              _buildBucketItem(
                context,
                title: 'Needs',
                target: 'Target: 50%',
                amount: summary.needsSpent,
                percent: summary.needsPercent,
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(width: 8),
              _buildBucketItem(
                context,
                title: 'Wants',
                target: 'Target: 30%',
                amount: summary.wantsSpent,
                percent: summary.wantsPercent,
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 8),
              _buildBucketItem(
                context,
                title: 'Savings',
                target: 'Target: 20%',
                amount: summary.savingsTransferred,
                percent: summary.savingsPercent,
                color: const Color(0xFF10B981),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBucketItem(
    BuildContext context, {
    required String title,
    required String target,
    required double amount,
    required double percent,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
                ),
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(amount),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              target,
              style: const TextStyle(fontSize: 9, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
