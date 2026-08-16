import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Overlay widget that obscures app content when the app goes to the
/// background (app switcher / recent apps). Prevents sensitive financial
/// data from being visible in OS screenshots and task switcher previews.
class PrivacyShieldWidget extends StatelessWidget {
  final bool isActive;
  final Widget child;

  const PrivacyShieldWidget({
    super.key,
    required this.isActive,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isActive)
          Positioned.fill(
            child: _PrivacyOverlay(),
          ),
      ],
    );
  }
}

class _PrivacyOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.darkBg : AppColors.lightBg,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.visibility_off_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Lumina Expense',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Content hidden for privacy',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
