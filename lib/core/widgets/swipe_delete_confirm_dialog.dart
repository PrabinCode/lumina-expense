import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_preferences_provider.dart';
import '../theme/app_colors.dart';
import 'sonner_toast.dart';

/// Asks the user to confirm a swipe-to-delete, unless they have turned the
/// confirmation off (Settings > App Preferences).
///
/// Returns `true` if the item should be moved to the Recycle Bin.
/// Use it inside a [Dismissible.confirmDismiss] callback.
Future<bool> confirmSwipeDelete(
  BuildContext context,
  WidgetRef ref, {
  required String itemName,
  String? detail,
}) async {
  if (!ref.read(appPreferencesProvider).confirmSwipeDelete) return true;

  final result = await showDialog<({bool confirmed, bool dontAskAgain})>(
    context: context,
    builder: (_) => _SwipeDeleteConfirmDialog(itemName: itemName, detail: detail),
  );

  if (result == null || !result.confirmed) return false;

  if (result.dontAskAgain) {
    await ref.read(appPreferencesProvider.notifier).setConfirmSwipeDelete(false);
    Sonner.info(
      'Swipe will now delete instantly',
      description: 'Turn confirmation back on in Settings > App Preferences',
    );
  }
  return true;
}

class _SwipeDeleteConfirmDialog extends StatefulWidget {
  final String itemName;
  final String? detail;

  const _SwipeDeleteConfirmDialog({required this.itemName, this.detail});

  @override
  State<_SwipeDeleteConfirmDialog> createState() => _SwipeDeleteConfirmDialogState();
}

class _SwipeDeleteConfirmDialogState extends State<_SwipeDeleteConfirmDialog> {
  bool _dontAskAgain = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.delete_outline_rounded, color: AppColors.expense),
          SizedBox(width: 10),
          Expanded(
            child: Text('Move to Recycle Bin?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.detail != null ? '${widget.itemName}  •  ${widget.detail}' : widget.itemName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          const Text(
            'You can restore it later from Settings > Recycle Bin.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _dontAskAgain = !_dontAskAgain),
            child: Row(
              children: [
                Checkbox(
                  value: _dontAskAgain,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _dontAskAgain = v ?? false),
                ),
                const Expanded(child: Text("Don't ask me again", style: TextStyle(fontSize: 14))),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, (confirmed: false, dontAskAgain: false)),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.expense,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.pop(context, (confirmed: true, dontAskAgain: _dontAskAgain)),
          child: const Text('Move to Bin'),
        ),
      ],
    );
  }
}
