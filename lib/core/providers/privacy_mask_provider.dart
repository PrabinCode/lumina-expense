import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyMaskNotifier extends StateNotifier<bool> {
  static const _keyMask = 'privacy_mask_enabled';
  static const _keyMaskOnLaunch = 'privacy_mask_on_launch';

  PrivacyMaskNotifier() : super(false) {
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final maskOnLaunch = prefs.getBool(_keyMaskOnLaunch) ?? false;
      if (maskOnLaunch) {
        state = true;
      } else {
        state = prefs.getBool(_keyMask) ?? false;
      }
    } catch (_) {}
  }

  Future<void> toggle() async {
    state = !state;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyMask, state);
    } catch (_) {}
  }

  Future<void> setMask(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyMask, value);
    } catch (_) {}
  }

  static Future<bool> isMaskOnLaunchEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyMaskOnLaunch) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setMaskOnLaunch(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyMaskOnLaunch, enabled);
    } catch (_) {}
  }
}

final privacyMaskProvider = StateNotifierProvider<PrivacyMaskNotifier, bool>((ref) {
  return PrivacyMaskNotifier();
});
