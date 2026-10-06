import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/icon_helper.dart';
import '../../providers/profile_providers.dart';
import 'profile_switcher_sheet.dart';

class ProfileAppBarPill extends ConsumerWidget {
  const ProfileAppBarPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProfile = ref.watch(activeProfileProvider);

    if (activeProfile == null) {
      return const SizedBox.shrink();
    }

    final color = Color(activeProfile.color);

    return InkWell(
      onTap: () => ProfileSwitcherSheet.show(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 10,
              backgroundColor: color.withValues(alpha: 0.25),
              child: Icon(
                IconHelper.getProfileIcon(activeProfile.icon),
                size: 12,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 90),
              child: Text(
                activeProfile.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
