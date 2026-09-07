import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../budgets/presentation/screens/budgets_screen.dart';
import '../../../debts/presentation/screens/debts_screen.dart';
import '../../../goals/presentation/screens/goals_screen.dart';
import '../../../transactions/presentation/screens/add_transaction_sheet.dart';
import '../../data/financial_health_service.dart';
import '../widgets/health_score_gauge.dart';

class FinancialHealthScreen extends ConsumerWidget {
  const FinancialHealthScreen({super.key});

  void _handleActionRoute(BuildContext context, String? route) {
    if (route == null) return;
    switch (route) {
      case 'budgets':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BudgetsScreen()),
        );
        break;
      case 'debts':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DebtsScreen()),
        );
        break;
      case 'goals':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GoalsScreen()),
        );
        break;
      case 'add_transaction':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const AddTransactionSheet(),
        );
        break;
    }
  }

  void _openHowScoringWorks(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _HowScoringWorksSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthState = ref.watch(financialHealthProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'Financial Health',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'How Scoring Works',
            onPressed: () => _openHowScoringWorks(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recalculate Score',
            onPressed: () => ref.refresh(financialHealthProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(financialHealthProvider),
        child: healthState.when(
          data: (report) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Hero Overview Card
                  _buildHeroCard(context, report, surfaceColor, borderColor, textColor, secondaryTextColor, isDark),
                  const SizedBox(height: 24),

                  // 2. Level Up Your Score (Roadmap)
                  if (report.actionRoadmap.isNotEmpty) ...[
                    _buildSectionHeader(
                      title: 'Level Up Your Score',
                      subtitle: 'Personalized high-impact actions to grow your wealth',
                      icon: Icons.auto_graph_rounded,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                    const SizedBox(height: 12),
                    ...report.actionRoadmap.map(
                      (task) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ActionRoadmapCard(
                          task: task,
                          onAction: () => _handleActionRoute(context, task.actionRoute),
                          isDark: isDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3. 5 Pillars Deep Dive Breakdown
                  _buildSectionHeader(
                    title: '5 Financial Pillars',
                    subtitle: 'Calculated with real numbers from your accounts',
                    icon: Icons.pie_chart_outline_rounded,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                  ),
                  const SizedBox(height: 12),
                  ...report.pillars.map(
                    (pillar) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _PillarCard(
                        pillar: pillar,
                        isDark: isDark,
                        onAction: () => _handleActionRoute(context, pillar.actionRoute),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Smart Insights
                  if (report.insights.isNotEmpty) ...[
                    _buildSectionHeader(
                      title: 'Observations & Insights',
                      subtitle: 'Patterns detected in your monthly spending behavior',
                      icon: Icons.lightbulb_outline_rounded,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                    const SizedBox(height: 12),
                    ...report.insights.map(
                      (insight) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildInsightCard(insight, surfaceColor, borderColor, isDark),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Bottom Methodology trigger
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _openHowScoringWorks(context),
                      icon: const Icon(Icons.info_outline_rounded, size: 16),
                      label: const Text(
                        'Learn how our scoring methodology works',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to calculate financial health\n$err',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textColor),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => ref.refresh(financialHealthProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: secondaryTextColor,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    FinancialHealthReport report,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color secondaryTextColor,
    bool isDark,
  ) {
    final tier = report.tier;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: tier.color.withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Animated Gauge
          HealthScoreGauge(
            score: report.overallScore,
            tier: tier,
            grade: report.grade,
            gradeColor: report.gradeColor,
            size: 210,
          ),
          const SizedBox(height: 20),

          // Tier Headline
          Text(
            tier.headline,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),

          // Tier Description
          Text(
            tier.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: secondaryTextColor,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),

          // Milestone Progress Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: tier.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: tier.color.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  size: 18,
                  color: tier.color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    report.pointsToNextMilestone > 0
                        ? 'Next Goal: Reach ${report.nextMilestoneLabel} (+${report.pointsToNextMilestone} pts)'
                        : '🌟 Peak Financial Tier: You are maintaining elite score health!',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(
    HealthInsight insight,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: priorityColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(insight.icon, color: priorityColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            insight.description,
                            style: TextStyle(
                              fontSize: 13,
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

// ─────────────────────────────────────────────────────────────────────────────
// Action Roadmap Card
// ─────────────────────────────────────────────────────────────────────────────
class _ActionRoadmapCard extends StatelessWidget {
  final HealthActionTask task;
  final VoidCallback onAction;
  final bool isDark;

  const _ActionRoadmapCard({
    required this.task,
    required this.onAction,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: task.impactColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(task.icon, size: 20, color: task.impactColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: task.impactColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: task.impactColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  task.impact,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: task.impactColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            task.description,
            style: TextStyle(
              fontSize: 13,
              color: secondaryTextColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.actionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expandable Pillar Card with 2x2 Key Metrics Grid
// ─────────────────────────────────────────────────────────────────────────────
class _PillarCard extends StatefulWidget {
  final PillarMetric pillar;
  final bool isDark;
  final VoidCallback onAction;

  const _PillarCard({
    required this.pillar,
    required this.isDark,
    required this.onAction,
  });

  @override
  State<_PillarCard> createState() => _PillarCardState();
}

class _PillarCardState extends State<_PillarCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final pillar = widget.pillar;
    final surfaceColor = widget.isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = widget.isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _expanded
              ? pillar.statusColor.withValues(alpha: 0.4)
              : borderColor,
          width: _expanded ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (Tappable to Expand/Collapse)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(18),
              bottom: Radius.circular(_expanded ? 0 : 18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: pillar.statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(pillar.icon, color: pillar.statusColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pillar.title,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              pillar.weightLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: pillar.statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${pillar.score.toInt()}/100 • ${pillar.statusLabel}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: pillar.statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: secondaryTextColor,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Headline
                  Text(
                    pillar.headline,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pillar.score / 100.0,
                      backgroundColor: widget.isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(pillar.statusColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // 2x2 Key Metrics Grid
                  if (pillar.keyMetrics.isNotEmpty) ...[
                    _buildMetricsGrid(pillar.keyMetrics, textColor, secondaryTextColor, widget.isDark),
                    const SizedBox(height: 14),
                  ],

                  // Benchmark Note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pillar.benchmark,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: secondaryTextColor,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Recommendation & Action
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pillar.statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: pillar.statusColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tips_and_updates_outlined, size: 16, color: pillar.statusColor),
                            const SizedBox(width: 8),
                            Text(
                              'Recommendation',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: pillar.statusColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          pillar.recommendation,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: textColor,
                            height: 1.4,
                          ),
                        ),
                        if (pillar.actionLabel != null) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonal(
                              onPressed: widget.onAction,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    pillar.actionLabel!,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward_rounded, size: 12),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(
    Map<String, String> metrics,
    Color textColor,
    Color secondaryTextColor,
    bool isDark,
  ) {
    final entries = metrics.entries.toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 8) / 2;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entries.map((entry) {
            return Container(
              width: itemWidth,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// How Scoring Works Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _HowScoringWorksSheet extends StatelessWidget {
  const _HowScoringWorksSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scoring Methodology',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Objective financial health benchmarks & weighting',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '5 Weighted Pillars',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPillarExplanation(
                    icon: Icons.savings_rounded,
                    color: const Color(0xFF10B981),
                    title: 'Savings Rate (30% weight)',
                    desc: 'Evaluates what percentage of your total income is saved each month. Benchmark: Saving 20%+ earns a score of 80 to 100.',
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                  ),
                  const SizedBox(height: 12),
                  _buildPillarExplanation(
                    icon: Icons.pie_chart_outline_rounded,
                    color: const Color(0xFF3B82F6),
                    title: 'Budget Adherence (25% weight)',
                    desc: 'Tracks how disciplined your spending is compared to your allocated budgets. If you do not have active budgets, setting them up unlocks an immediate score boost.',
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                  ),
                  const SizedBox(height: 12),
                  _buildPillarExplanation(
                    icon: Icons.shield_outlined,
                    color: const Color(0xFF14B8A6),
                    title: 'Debt Freedom (20% weight)',
                    desc: 'Compares your total active liabilities to your monthly income. Keeping debt payments low or debt-free gives you maximum security and top marks.',
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                  ),
                  const SizedBox(height: 12),
                  _buildPillarExplanation(
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFF8B5CF6),
                    title: 'Cash Flow Trend (15% weight)',
                    desc: 'Analyzes your net surplus over 3 months. Sustained positive cash flow ensures resilience against unexpected life emergencies.',
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                  ),
                  const SizedBox(height: 12),
                  _buildPillarExplanation(
                    icon: Icons.speed_rounded,
                    color: const Color(0xFFF59E0B),
                    title: 'Spending Consistency (10% weight)',
                    desc: 'Measures expense predictability. Stable weekly and monthly spending prevents shock deficits.',
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Health Tiers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTierRow('🌟', 'Thriving (90 - 100)', 'Exceptional savings, zero distress debt, thriving cash flow.', const Color(0xFF10B981), textColor, secondaryTextColor),
                  _buildTierRow('🟢', 'Strong (75 - 89)', 'Solid financial foundation, consistent surplus, reliable budget adherence.', const Color(0xFF14B8A6), textColor, secondaryTextColor),
                  _buildTierRow('🔵', 'Fair (60 - 74)', 'Balanced cash flow with healthy potential to grow and optimize.', const Color(0xFF3B82F6), textColor, secondaryTextColor),
                  _buildTierRow('🟡', 'Needs Attention (45 - 59)', 'Spending approaching or exceeding income. Focused budget trims recommended.', const Color(0xFFF59E0B), textColor, secondaryTextColor),
                  _buildTierRow('🔴', 'At Risk (0 - 44)', 'High financial stress zone. Cash outflow outstripping inflows.', const Color(0xFFEF4444), textColor, secondaryTextColor),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Got It',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarExplanation({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12.5,
                  color: secondaryTextColor,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTierRow(
    String emoji,
    String title,
    String desc,
    Color color,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
