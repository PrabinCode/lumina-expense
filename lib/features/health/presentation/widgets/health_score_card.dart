import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/financial_health_service.dart';
import 'health_score_gauge.dart';
import '../screens/financial_health_screen.dart';

class HealthScoreCard extends ConsumerWidget {
  const HealthScoreCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthState = ref.watch(financialHealthProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const FinancialHealthScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: healthState.when(
            data: (report) {
              final tier = report.tier;
              final topTask = report.actionRoadmap.isNotEmpty ? report.actionRoadmap.first : null;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  HealthScoreGauge(
                    score: report.overallScore,
                    tier: tier,
                    grade: report.grade,
                    gradeColor: report.gradeColor,
                    size: 80,
                    showTierBadge: false,
                    showSubtext: false,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Financial Health',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: tier.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: tier.color.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${tier.icon} ${tier.label}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: tier.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tier.headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (topTask != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: topTask.impactColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  topTask.icon,
                                  size: 13,
                                  color: topTask.impactColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    topTask.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: topTask.impactColor,
                                    ),
                                  ),
                                ),
                                Text(
                                  topTask.impact,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: topTask.impactColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (report.insights.isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                report.insights.first.icon,
                                size: 13,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  report.insights.first.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'Tap to explore scoring breakdown',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: secondaryTextColor.withValues(alpha: 0.7),
                    size: 20,
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  'Tap to recalculate health score',
                  style: TextStyle(color: AppColors.expense, fontSize: 13),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
