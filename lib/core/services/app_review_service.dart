import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

final appReviewServiceProvider = Provider<AppReviewService>((ref) {
  return AppReviewService();
});

class AppReviewService {
  static const String playStorePackageId = 'com.prabincode.luminaexpense';
  static const String _keyLastReviewTimestamp = 'review_last_prompt_timestamp';
  static const String _keyTotalPrompts = 'review_total_prompt_count';
  static const String _keyTransactionsLogged = 'review_tx_logged_count';
  static const String _keyGoalsCompleted = 'review_goals_completed_count';
  static const String _keyBackupCompleted = 'review_backup_completed';

  final InAppReview _inAppReview = InAppReview.instance;

  /// Open Google Play Store listing directly for rating and review.
  Future<void> openStoreReview() async {
    try {
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        final isAvailable = await _inAppReview.isAvailable();
        if (isAvailable) {
          await _inAppReview.openStoreListing(appStoreId: playStorePackageId);
          return;
        }
      }
    } catch (e) {
      debugPrint('InAppReview openStoreListing error: $e');
    }

    // Direct URL Fallback
    final url = Uri.parse('https://play.google.com/store/apps/details?id=$playStorePackageId');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch Play Store URL: $e');
    }
  }

  /// Request an in-app review dialog via Google Play Core API if milestone & cooldown conditions are met.
  Future<bool> checkAndPromptMilestoneReview({String reason = 'milestone'}) async {
    try {
      if (kIsWeb || !Platform.isAndroid) return false;

      final isAvailable = await _inAppReview.isAvailable();
      if (!isAvailable) return false;

      final prefs = await SharedPreferences.getInstance();

      // Check prompt cooldown (minimum 30 days between automated review requests)
      final lastPromptStr = prefs.getString(_keyLastReviewTimestamp);
      if (lastPromptStr != null) {
        final lastPrompt = DateTime.tryParse(lastPromptStr);
        if (lastPrompt != null) {
          final daysSince = DateTime.now().difference(lastPrompt).inDays;
          if (daysSince < 30) {
            return false;
          }
        }
      }

      // Check max total automated prompts to prevent annoying users
      final totalPrompts = prefs.getInt(_keyTotalPrompts) ?? 0;
      if (totalPrompts >= 3) {
        return false;
      }

      debugPrint('AppReviewService: Prompting in-app review for reason: $reason');
      await _inAppReview.requestReview();

      // Record timestamp and count
      await prefs.setString(_keyLastReviewTimestamp, DateTime.now().toIso8601String());
      await prefs.setInt(_keyTotalPrompts, totalPrompts + 1);
      return true;
    } catch (e) {
      debugPrint('AppReviewService.requestReview error: $e');
      return false;
    }
  }

  /// Record milestone: goal reached 100% completion
  Future<void> recordGoalCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_keyGoalsCompleted) ?? 0) + 1;
    await prefs.setInt(_keyGoalsCompleted, count);

    // Prompt review on first or third completed goal
    if (count == 1 || count == 3) {
      await checkAndPromptMilestoneReview(reason: 'goal_completed_$count');
    }
  }

  /// Record milestone: transaction logged
  Future<void> recordTransactionLogged() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_keyTransactionsLogged) ?? 0) + 1;
    await prefs.setInt(_keyTransactionsLogged, count);

    // Prompt review after 15th transaction
    if (count == 15) {
      await checkAndPromptMilestoneReview(reason: 'transactions_15_logged');
    }
  }

  /// Record milestone: first manual backup created
  Future<void> recordBackupCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool(_keyBackupCompleted) ?? false;
    if (!alreadyPrompted) {
      await prefs.setBool(_keyBackupCompleted, true);
      await checkAndPromptMilestoneReview(reason: 'first_backup_completed');
    }
  }
}
