import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  DateTime? _pausedAt;
  bool _initialized = false;
  bool _isAuthenticating = false;
  String? _lastError;

  bool get isLocked => _isLocked;
  bool get isEnabled => _isEnabled;
  bool get privacyShieldEnabled => _privacyShieldEnabled;
  LockTimeout get timeout => _timeout;
  bool get initialized => _initialized;
  bool get isAuthenticating => _isAuthenticating;
  String? get lastError => _lastError;

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
    if (_isAuthenticating) return false;
    _isAuthenticating = true;
    _lastError = null;

    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        _lastError = 'Biometrics / device PIN not available or not configured.';
        _isAuthenticating = false;
        notifyListeners();
        return false;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow device PIN/pattern/passcode as fallback
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );

      if (authenticated) {
        _isLocked = false;
        _pausedAt = null;
        _lastError = null;
      } else {
        _lastError = 'Authentication cancelled or not recognized.';
      }

      _isAuthenticating = false;
      notifyListeners();
      return authenticated;
    } on PlatformException catch (e) {
      debugPrint('LocalAuth PlatformException: ${e.code} - ${e.message}');
      if (e.code == 'NotAvailable') {
        _lastError = 'Biometrics or device passcode not available on this device.';
      } else if (e.code == 'PasscodeNotSet') {
        _lastError = 'Please set up a screen lock (PIN/Password) in system Settings.';
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        _lastError = 'Too many attempts. Unlock with device passcode or wait a moment.';
      } else {
        _lastError = e.message ?? 'Authentication error (${e.code}).';
      }
      _isAuthenticating = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Authentication unexpected error: $e');
      _lastError = 'Authentication error: $e';
      _isAuthenticating = false;
      notifyListeners();
      return false;
    }
  }

  /// Enable or disable app lock
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      // Verify biometrics/passcode are available before enabling
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
    _pausedAt = null;
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
    // Don't record pause during active biometric prompt
    if (_isAuthenticating) return;

    _pausedAt = DateTime.now();
  }

  /// Called when app comes to foreground — determine if lock screen needed
  void onAppResumed() {
    if (!_isEnabled || _isLocked) return;
    // Don't lock when returning from system biometric dialog
    if (_isAuthenticating) return;

    if (_pausedAt != null) {
      final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
      if (elapsed >= _timeout.seconds) {
        _isLocked = true;
        _pausedAt = null;
        notifyListeners();
      }
    }
  }

  /// Force lock (e.g. manual lock from settings)
  void lock() {
    if (!_isEnabled) return;
    _isLocked = true;
    _pausedAt = null;
    notifyListeners();
  }
}

/// Global AppLockService provider
final appLockServiceProvider = ChangeNotifierProvider<AppLockService>((ref) {
  final service = AppLockService();
  service.initialize();
  return service;
});
