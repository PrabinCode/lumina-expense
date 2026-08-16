import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/financial_health_service.dart';
import '../widgets/health_score_gauge.dart';

class FinancialHealthScreen extends ConsumerWidget {
  const FinancialHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthState = ref.watch(financialHealthProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Financial Health'),
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.refresh(financialHealthProvider),
            tooltip: 'Recalculate Health Score',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(financialHealthProvider),
        child: healthState.when(
          data: (report) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero Section
                _buildHeroSection(report, surfaceColor, borderColor, textColor),
                const SizedBox(height: 24),
                
                // Component Breakdown
                Text(
                  'Score Breakdown',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                _buildComponentsCard(report, surfaceColor, borderColor, isDark),
                const SizedBox(height: 24),
                
                // Smart Insights
                Text(
                  'Smart Insights',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                ...report.insights.map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildInsightCard(insight, surfaceColor, borderColor, isDark),
                )),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.expense, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Failed to load data\n$err',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildHeroSection(FinancialHealthReport report, Color surfaceColor, Color borderColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          HealthScoreGauge(
            score: report.overallScore,
            grade: report.grade,
            gradeColor: report.gradeColor,
            size: 220,
          ),
          const SizedBox(height: 24),
          Text(
            'Your financial health is looking ${report.overallScore >= 70 ? 'great' : 'okay'}.',
            style: TextStyle(
              fontSize: 16,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentsCard(FinancialHealthReport report, Color surfaceColor, Color borderColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _buildScoreBar('Savings Rate', report.savingsRateScore, isDark),
          const SizedBox(height: 16),
          _buildScoreBar('Budget Adherence', report.budgetScore, isDark),
          const SizedBox(height: 16),
          _buildScoreBar('Expense Consistency', report.consistencyScore, isDark),
          const SizedBox(height: 16),
          _buildScoreBar('Income Trend', report.trendScore, isDark),
          const SizedBox(height: 16),
          _buildScoreBar('Debt Health', report.debtScore, isDark),
        ],
      ),
    );
  }

  Widget _buildScoreBar(String label, double score, bool isDark) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    Color barColor;
    if (score >= 80) {
      barColor = AppColors.primary;
    } else if (score >= 60) {
      barColor = AppColors.transfer;
    } else if (score >= 40) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.expense;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
            Text('${score.toInt()}/100', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: score / 100,
          backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          valueColor: AlwaysStoppedAnimation<Color>(barColor),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildInsightCard(HealthInsight insight, Color surfaceColor, Color borderColor, bool isDark) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    
    Color priorityColor;
    switch (insight.priority) {
      case InsightPriority.high:
        priorityColor = AppColors.expense;
        break;
      case InsightPriority.medium:
        priorityColor = AppColors.warning;
        break;
      case InsightPriority.low:
        priorityColor = AppColors.primary;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 6,
              color: priorityColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(insight.icon, color: priorityColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            insight.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: secondaryTextColor,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
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
