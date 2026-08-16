import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App lock timeout options in seconds
enum LockTimeout {
  immediate(0, 'Immediately'),
  oneMinute(60, '1 minute'),
  fiveMinutes(300, '5 minutes'),
  fifteenMinutes(900, '15 minutes'),
  thirtyMinutes(1800, '30 minutes');

  final int seconds;
  final String label;
  const LockTimeout(this.seconds, this.label);
}

/// Manages biometric/device-credential app lock state
class AppLockService extends ChangeNotifier {
  static const _keyEnabled = 'app_lock_enabled';
  static const _keyTimeout = 'app_lock_timeout_seconds';
  static const _keyPrivacyShield = 'privacy_shield_enabled';

  final LocalAuthentication _auth = LocalAuthentication();
  SharedPreferences? _prefs;

  bool _isLocked = false;
  bool _isEnabled = false;
  bool _privacyShieldEnabled = true;
  LockTimeout _timeout = LockTimeout.immediate;
  DateTime? _lastUnlockedAt;
  bool _initialized = false;

  bool get isLocked => _isLocked;
  bool get isEnabled => _isEnabled;
  bool get privacyShieldEnabled => _privacyShieldEnabled;
  LockTimeout get timeout => _timeout;
  bool get initialized => _initialized;

  /// Initialize from persisted preferences
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _isEnabled = _prefs!.getBool(_keyEnabled) ?? false;
    _privacyShieldEnabled = _prefs!.getBool(_keyPrivacyShield) ?? true;
    final timeoutSeconds = _prefs!.getInt(_keyTimeout) ?? 0;
    _timeout = LockTimeout.values.firstWhere(
      (t) => t.seconds == timeoutSeconds,
      orElse: () => LockTimeout.immediate,
    );

    // If lock is enabled, start locked
    if (_isEnabled) {
      _isLocked = true;
    }

    _initialized = true;
    notifyListeners();
  }

  /// Check if biometric or device credential auth is available
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Attempt to authenticate the user
  Future<bool> authenticate({String reason = 'Unlock Lumina Expense'}) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow device PIN/pattern as fallback
        ),
      );

      if (authenticated) {
        _isLocked = false;
        _lastUnlockedAt = DateTime.now();
        notifyListeners();
      }

      return authenticated;
    } catch (e) {
      debugPrint('Authentication error: $e');
      return false;
    }
  }

  /// Enable or disable app lock
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      // Verify biometrics are available before enabling
      final available = await isBiometricAvailable();
      if (!available) return;

      // Authenticate first to confirm identity
      final authenticated = await authenticate(
        reason: 'Verify your identity to enable app lock',
      );
      if (!authenticated) return;
    }

    _isEnabled = enabled;
    _isLocked = false;
    _lastUnlockedAt = DateTime.now();
    await _prefs?.setBool(_keyEnabled, enabled);
    notifyListeners();
  }

  /// Set the lock timeout
  Future<void> setTimeout(LockTimeout timeout) async {
    _timeout = timeout;
    await _prefs?.setInt(_keyTimeout, timeout.seconds);
    notifyListeners();
  }

  /// Toggle privacy shield
  Future<void> setPrivacyShield(bool enabled) async {
    _privacyShieldEnabled = enabled;
    await _prefs?.setBool(_keyPrivacyShield, enabled);
    notifyListeners();
  }

  /// Called when app goes to background — check if should lock
  void onAppPaused() {
    if (!_isEnabled) return;
    // Record the time we went to background
    _lastUnlockedAt = DateTime.now();
  }

  /// Called when app comes to foreground — determine if lock screen needed
  void onAppResumed() {
    if (!_isEnabled || _isLocked) return;

    if (_lastUnlockedAt == null) {
      _isLocked = true;
      notifyListeners();
      return;
    }

    final elapsed = DateTime.now().difference(_lastUnlockedAt!).inSeconds;
    if (elapsed >= _timeout.seconds) {
      _isLocked = true;
      notifyListeners();
    }
  }

  /// Force lock (e.g. manual lock from settings)
  void lock() {
    if (!_isEnabled) return;
    _isLocked = true;
    _lastUnlockedAt = null;
    notifyListeners();
  }
}

/// Global AppLockService provider
final appLockServiceProvider = ChangeNotifierProvider<AppLockService>((ref) {
  final service = AppLockService();
  service.initialize();
  return service;
});
