import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_review_service.dart';
import '../../../../core/theme/app_colors.dart';

class WhatsNewSheet extends ConsumerWidget {
  final String appVersion;

  const WhatsNewSheet({super.key, required this.appVersion});

  static Future<void> show(BuildContext context, {required String appVersion}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => WhatsNewSheet(appVersion: appVersion),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final features = [
      (
        icon: Icons.edit_note_rounded,
        color: const Color(0xFF10B981),
        title: 'No More Lost Drafts',
        description: 'Adding a transaction or writing feedback? Pressing Back or tapping outside now asks before discarding what you entered. Edits only prompt if you actually changed something.',
      ),
      (
        icon: Icons.vertical_align_bottom_rounded,
        color: const Color(0xFF3B82F6),
        title: 'Buttons Stay Above the Nav Bar',
        description: 'Feedback, Analytics, Budgets, Recycle Bin, Theme and Net Worth sheets keep their bottom buttons fully visible on edge-to-edge phones.',
      ),
      (
        icon: Icons.delete_sweep_rounded,
        color: const Color(0xFFEF4444),
        title: 'Swipe-to-Delete Confirmation',
        description: 'Swiping left asks "Move to Recycle Bin?" first. Tick "Don\'t ask me again" to keep instant delete; change it anytime in App Preferences.',
      ),
      (
        icon: Icons.swipe_rounded,
        color: const Color(0xFFF59E0B),
        title: 'Quick Gestures & App Tour',
        description: 'A new animated onboarding slide shows swipe and long-press gestures, and Settings › App Tour & Guide explains every feature with "Go there" shortcuts.',
      ),
      (
        icon: Icons.phone_android_rounded,
        color: const Color(0xFF8B5CF6),
        title: 'Ready for Android 15 & 16',
        description: 'Edge-to-edge display, rotation on tablets and foldables, and smaller, faster release builds.',
      ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "What's New in Lumina",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Version $appVersion highlights',
                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'v$appVersion',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),

            // Feature list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: features.length,
                separatorBuilder: (_, index) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final item = features[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceVariant.withValues(alpha: 0.4)
                          : AppColors.lightSurfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.icon, color: item.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.star_rate_rounded, size: 18, color: Color(0xFFF59E0B)),
                    label: const Text('Rate on Play Store'),
                    onPressed: () {
                      Navigator.pop(context);
                      ref.read(appReviewServiceProvider).openStoreReview();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got it!'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
