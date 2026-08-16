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

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const FinancialHealthScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: healthState.when(
          data: (report) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                HealthScoreGauge(
                  score: report.overallScore,
                  grade: report.grade,
                  gradeColor: report.gradeColor,
                  size: 80,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Financial Health',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (report.insights.isNotEmpty) ...[
                        _buildMiniInsight(report.insights.first, secondaryTextColor),
                        if (report.insights.length > 1) ...[
                          const SizedBox(height: 4),
                          _buildMiniInsight(report.insights[1], secondaryTextColor),
                        ],
                      ] else
                        Text(
                          'Looking good!',
                          style: TextStyle(color: secondaryTextColor, fontSize: 13),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: secondaryTextColor,
                ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, stack) => Center(
            child: Text(
              'Failed to load health score',
              style: TextStyle(color: AppColors.expense),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniInsight(HealthInsight insight, Color textColor) {
    Color iconColor;
    switch (insight.priority) {
      case InsightPriority.high:
        iconColor = AppColors.expense;
        break;
      case InsightPriority.medium:
        iconColor = AppColors.warning;
        break;
      case InsightPriority.low:
        iconColor = AppColors.primary;
        break;
    }

    return Row(
      children: [
        Icon(insight.icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            insight.title,
            style: TextStyle(
              fontSize: 13,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
