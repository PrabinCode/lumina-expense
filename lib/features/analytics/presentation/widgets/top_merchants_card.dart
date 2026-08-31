import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../domain/models/analytics_models.dart';

class TopMerchantsCard extends StatelessWidget {
  final List<TopMerchantItem> merchants;

  const TopMerchantsCard({
    super.key,
    required this.merchants,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (merchants.isEmpty) {
      return const SizedBox.shrink();
    }

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
            children: [
              Icon(Icons.storefront_rounded, size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Top Payees & Merchants',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: merchants.length,
            separatorBuilder: (context, index) => const Divider(height: 16),

            itemBuilder: (context, index) {
              final m = merchants[index];
              final iconColor = m.categoryColor != null ? Color(m.categoryColor!) : AppColors.primary;

              return Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (m.categoryIcon != null) ...[
                    Icon(
                      IconHelper.getCategoryIcon(m.categoryIcon!),
                      size: 18,
                      color: iconColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${m.transactionCount} transaction${m.transactionCount > 1 ? "s" : ""}',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(m.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
