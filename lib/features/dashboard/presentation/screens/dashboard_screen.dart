import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../health/presentation/widgets/health_score_card.dart';
import '../widgets/dashboard_goals_card.dart';
import '../widgets/dashboard_subscriptions_card.dart';
import '../widgets/quick_actions_bar.dart';
import '../widgets/recent_transactions_list.dart';
import '../widgets/total_balance_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF10B981), size: 24),
            SizedBox(width: 8),
            Text('Lumina Expense'),
          ],
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TotalBalanceCard(),
            SizedBox(height: 16),
            QuickActionsBar(),
            SizedBox(height: 16),
            HealthScoreCard(),
            SizedBox(height: 16),
            DashboardGoalsCard(),
            DashboardSubscriptionsCard(),
            RecentTransactionsList(),
            SizedBox(height: 80), // Padding for navigation bar
          ],
        ),
      ),
    );
  }
}
