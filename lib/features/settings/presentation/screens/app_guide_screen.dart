import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gesture_demo_card.dart';
import '../../../backup/presentation/screens/backup_screen.dart';
import '../../../budgets/presentation/screens/budgets_screen.dart';
import '../../../debts/presentation/screens/debts_screen.dart';
import '../../../goals/presentation/screens/goals_screen.dart';
import '../../../health/presentation/screens/financial_health_screen.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';
import '../../../recycle_bin/presentation/screens/recycle_bin_screen.dart';
import '../../../subscriptions/presentation/screens/subscriptions_screen.dart';
import 'regional_preferences_screen.dart';

/// "App Tour & Guide": a browsable reference of features, gestures and
/// where settings live. Each topic expands to short tips and "Go there" links.
class AppGuideScreen extends StatelessWidget {
  const AppGuideScreen({super.key});

  static final List<_GuideTopic> _topics = [
    _GuideTopic(
      icon: Icons.swipe_rounded,
      color: AppColors.warning,
      title: 'Quick Gestures',
      subtitle: 'Swipe, long-press & shortcuts',
      showGestureDemo: true,
      tips: const [
        _Tip(Icons.swipe_right_rounded, 'Swipe right on a transaction to edit it.'),
        _Tip(Icons.swipe_left_rounded,
            'Swipe left to move it to the Recycle Bin. Tap UNDO on the toast to bring it back.'),
        _Tip(Icons.touch_app_rounded,
            'Long-press a transaction on Home to start selecting. Tap more rows, then use the action bar to act on all of them.'),
        _Tip(Icons.verified_user_outlined,
            'Swipe delete asks for confirmation by default. You can turn this off in App Preferences.'),
        _Tip(Icons.apps_rounded,
            'Long-press the Lumina icon on your home screen for shortcuts: Add Expense, Add Income and Health Score.'),
      ],
      actions: [
        _GuideAction('Swipe settings', (_) => const RegionalPreferencesScreen()),
      ],
    ),
    _GuideTopic(
      icon: Icons.add_circle_outline_rounded,
      color: AppColors.primary,
      title: 'Adding Transactions',
      subtitle: 'Keypad math, splits & transfers',
      tips: const [
        _Tip(Icons.add_rounded, 'Tap the + button at the bottom of the screen to add an expense, income or transfer.'),
        _Tip(Icons.calculate_outlined,
            'The keypad works like a calculator: type 120+45 or 300/3 and the total is used as the amount.'),
        _Tip(Icons.call_split_rounded, 'Split one payment across several categories using the split option.'),
        _Tip(Icons.swap_horiz_rounded, 'Use Transfer to move money between your own accounts without counting it as spending.'),
      ],
    ),
    _GuideTopic(
      icon: Icons.document_scanner_outlined,
      color: Color(0xFF3B82F6),
      title: 'Receipts & Scanning',
      subtitle: 'Attach, crop & auto-fill',
      tips: const [
        _Tip(Icons.receipt_long_rounded, 'Attach a receipt photo to any transaction, and crop it before saving.'),
        _Tip(Icons.auto_awesome_rounded,
            'Scanning reads the amount, date and merchant on the device. It can also suggest a category and list items in Notes.'),
        _Tip(Icons.visibility_off_outlined, 'Receipt images are hidden from your phone\'s gallery.'),
        _Tip(Icons.tune_rounded, 'Change how scanned dates are read and what gets auto-filled in App Preferences.'),
      ],
      actions: [
        _GuideAction('Scanner settings', (_) => const RegionalPreferencesScreen()),
      ],
    ),
    _GuideTopic(
      icon: Icons.pie_chart_outline_rounded,
      color: AppColors.secondary,
      title: 'Budgets, Goals & Debts',
      subtitle: 'Plan and stay on track',
      tips: const [
        _Tip(Icons.donut_large_rounded, 'Budgets set a monthly limit per category and warn you as you get close.'),
        _Tip(Icons.savings_outlined, 'Savings Goals track progress toward something you\'re saving for.'),
        _Tip(Icons.handshake_outlined, 'Debts record money you lent or borrowed, including partial repayments.'),
        _Tip(Icons.autorenew_rounded, 'Subscriptions remind you of recurring bills and can log them for you.'),
      ],
      actions: [
        _GuideAction('Budgets', (_) => const BudgetsScreen()),
        _GuideAction('Goals', (_) => const GoalsScreen()),
        _GuideAction('Debts', (_) => const DebtsScreen()),
        _GuideAction('Subscriptions', (_) => const SubscriptionsScreen()),
      ],
    ),
    _GuideTopic(
      icon: Icons.insights_rounded,
      color: AppColors.transfer,
      title: 'Analytics & Health Score',
      subtitle: 'Understand your spending',
      tips: const [
        _Tip(Icons.bar_chart_rounded,
            'The Analytics tab shows cash flow, top categories and trends for any period. Tap a category or period to see its transactions.'),
        _Tip(Icons.favorite_border_rounded,
            'Health Score rates your savings rate, budget adherence and debt, and suggests what to improve.'),
      ],
      actions: [
        _GuideAction('Health Score', (_) => const FinancialHealthScreen()),
      ],
    ),
    _GuideTopic(
      icon: Icons.cloud_sync_outlined,
      color: AppColors.primary,
      title: 'Backup, Import & Recycle Bin',
      subtitle: 'Keep your data safe',
      tips: const [
        _Tip(Icons.backup_outlined,
            'Your data lives only on this device. Make regular backups so you can restore after changing or resetting your phone.'),
        _Tip(Icons.upload_file_rounded, 'Import transactions from a CSV file, such as a bank export, from Backup & Restore.'),
        _Tip(Icons.delete_outline_rounded,
            'Deleted transactions, budgets and debts go to the Recycle Bin first, so you can restore them.'),
      ],
      actions: [
        _GuideAction('Backup & Restore', (_) => const BackupScreen()),
        _GuideAction('Recycle Bin', (_) => const RecycleBinScreen()),
      ],
    ),
    _GuideTopic(
      icon: Icons.shield_outlined,
      color: AppColors.expense,
      title: 'Security & Privacy',
      subtitle: 'Lock, hide & mask',
      tips: const [
        _Tip(Icons.fingerprint_rounded,
            'Turn on Biometric App Lock in Settings › Security & Privacy to require a fingerprint, face or PIN.'),
        _Tip(Icons.visibility_off_rounded, 'Privacy Shield hides the app\'s contents in the recent-apps screen.'),
        _Tip(Icons.remove_red_eye_outlined,
            'Tap the eye icon on Home, or long-press your balance card, to hide all amounts when others can see your screen.'),
      ],
    ),
    _GuideTopic(
      icon: Icons.map_outlined,
      color: Color(0xFF6366F1),
      title: 'Where Settings Live',
      subtitle: 'Quick map of the Settings tab',
      tips: const [
        _Tip(Icons.tune_rounded,
            'App Preferences: date, time and number formats, receipt scanning, and swipe-to-delete confirmation.'),
        _Tip(Icons.account_balance_wallet_outlined,
            'Accounts & Wallets and Categories: add or edit them. Drag categories to reorder them.'),
        _Tip(Icons.palette_outlined, 'Theme & Palette: switch between light and dark mode and pick an accent colour.'),
        _Tip(Icons.storage_rounded, 'Storage & Maintenance: clean the cache and check your data for problems.'),
        _Tip(Icons.feedback_outlined, 'Feedback (in About & Support): send a bug report or idea straight to the developer.'),
      ],
      actions: [
        _GuideAction('App Preferences', (_) => const RegionalPreferencesScreen()),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('App Tour & Guide')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Tips and shortcuts for getting the most out of Lumina. Tap a topic to expand it.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < _topics.length; i++) ...[
              _TopicCard(topic: _topics[i], isDark: isDark, initiallyExpanded: i == 0),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OnboardingScreen(isViewingOnly: true)),
              ),
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('Replay Welcome Tour'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideTopic {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<_Tip> tips;
  final List<_GuideAction> actions;
  final bool showGestureDemo;

  const _GuideTopic({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.tips,
    this.actions = const [],
    this.showGestureDemo = false,
  });
}

class _Tip {
  final IconData icon;
  final String text;

  const _Tip(this.icon, this.text);
}

class _GuideAction {
  final String label;
  final WidgetBuilder builder;

  const _GuideAction(this.label, this.builder);
}

class _TopicCard extends StatelessWidget {
  final _GuideTopic topic;
  final bool isDark;
  final bool initiallyExpanded;

  const _TopicCard({required this.topic, required this.isDark, required this.initiallyExpanded});

  @override
  Widget build(BuildContext context) {
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Theme(
        // Remove the default ExpansionTile divider lines
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: topic.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(topic.icon, color: topic.color, size: 20),
          ),
          title: Text(topic.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: Text(topic.subtitle, style: TextStyle(fontSize: 12, color: secondary)),
          children: [
            if (topic.showGestureDemo) ...[
              const GestureDemoCard(),
              const SizedBox(height: 12),
            ],
            for (final tip in topic.tips)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(tip.icon, size: 17, color: topic.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(tip.text, style: const TextStyle(fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
              ),
            if (topic.actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final action in topic.actions)
                      ActionChip(
                        avatar: Icon(Icons.arrow_forward_rounded, size: 16, color: topic.color),
                        label: Text(action.label),
                        labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: topic.color),
                        backgroundColor: topic.color.withValues(alpha: 0.08),
                        side: BorderSide(color: topic.color.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: action.builder)),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
