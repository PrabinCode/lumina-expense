import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

class AppUpdateService {
  static const String playStorePackageId = 'com.prabincode.luminaexpense';
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=$playStorePackageId';

  AppUpdateInfo? _updateInfo;
  bool _isChecking = false;

  AppUpdateInfo? get updateInfo => _updateInfo;

  /// Check for updates with optional user-facing feedback.
  Future<void> checkForUpdate({
    required BuildContext context,
    bool showFeedbackIfUpToDate = false,
  }) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      if (kIsWeb || !Platform.isAndroid) {
        if (showFeedbackIfUpToDate && context.mounted) {
          _showPlatformUnavailableDialog(context);
        }
        return;
      }

      // Check update info from Google Play Core
      final info = await InAppUpdate.checkForUpdate();
      _updateInfo = info;

      if (!context.mounted) return;

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Update is ready in Play Store
        if (info.flexibleUpdateAllowed) {
          _promptFlexibleUpdate(context);
        } else if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else {
          _promptPlayStoreRedirect(context);
        }
      } else {
        if (showFeedbackIfUpToDate) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You are using the latest version of Lumina Expense!',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('InAppUpdate error (app may not be from Play Store or in debug): $e');
      if (showFeedbackIfUpToDate && context.mounted) {
        _showNonPlayStoreDialog(context, e.toString());
      }
    } finally {
      _isChecking = false;
    }
  }

  /// Silent background check on app startup (non-blocking)
  Future<void> checkSilentlyOnStartup(BuildContext context) async {
    try {
      if (kIsWeb || !Platform.isAndroid) return;
      final info = await InAppUpdate.checkForUpdate();
      _updateInfo = info;

      if (info.updateAvailability == UpdateAvailability.updateAvailable && info.flexibleUpdateAllowed) {
        // Start downloading in background
        await InAppUpdate.startFlexibleUpdate();
        if (context.mounted) {
          _showRestartSnackBar(context);
        }
      }
    } catch (e) {
      // Sideloaded / debug builds fail silently on startup
      debugPrint('Silent update check skipped: $e');
    }
  }

  void _promptFlexibleUpdate(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.system_update_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Update Available', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: const Text(
            'A new version of Lumina Expense is available on Google Play. Would you like to download it in the background while continuing to use the app?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Later'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await InAppUpdate.startFlexibleUpdate();
                  if (context.mounted) {
                    _showRestartSnackBar(context);
                  }
                } catch (e) {
                  debugPrint('Flexible update start error: $e');
                }
              },
              child: const Text('Download Update'),
            ),
          ],
        );
      },
    );
  }

  void _showRestartSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('New update downloaded and ready to install!'),
        duration: const Duration(days: 1),
        backgroundColor: const Color(0xFF6366F1),
        action: SnackBarAction(
          label: 'RESTART',
          textColor: Colors.white,
          onPressed: () {
            InAppUpdate.completeFlexibleUpdate();
          },
        ),
      ),
    );
  }

  void _promptPlayStoreRedirect(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Update Available', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'A new update is available on Google Play. Please visit the Play Store page to download the latest release.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _launchPlayStore();
              },
              child: const Text('Open Google Play'),
            ),
          ],
        );
      },
    );
  }

  void _showNonPlayStoreDialog(BuildContext context, String errorDetails) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Check for Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: const Text(
            'Google Play In-App Updates are active for app versions downloaded via Google Play Store (including Closed Testing).\n\nIf you are running a sideloaded APK or debug build, you can check for latest releases on Google Play or GitHub.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _launchUrl('https://github.com/PrabinCode/lumina-expense/releases');
              },
              child: const Text('GitHub'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(dialogContext);
                _launchPlayStore();
              },
              child: const Text('Google Play'),
            ),
          ],
        );
      },
    );
  }

  void _showPlatformUnavailableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Platform Update Notice'),
          content: const Text(
            'In-App updates via Google Play Core are supported on Android devices. You can check GitHub for desktop releases.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
          ],
        );
      },
    );
  }

  Future<void> _launchPlayStore() async {
    _launchUrl(playStoreUrl);
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch URL: $e');
    }
  }
}
