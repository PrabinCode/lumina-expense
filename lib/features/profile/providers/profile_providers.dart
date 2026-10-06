import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/currency_provider.dart';
import '../data/profile_repository.dart';

class ActiveProfileNotifier extends StateNotifier<String> {
  static const _keyActiveProfileId = 'active_profile_id';
  final Ref _ref;

  ActiveProfileNotifier(this._ref) : super('default_profile') {
    _loadActiveProfile();
  }

  Future<void> _loadActiveProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_keyActiveProfileId);
      if (savedId != null && savedId.isNotEmpty) {
        final profile = await _ref.read(profileRepositoryProvider).getProfileById(savedId);
        if (profile != null) {
          state = savedId;
          return;
        }
      }

      // If savedId is missing or no longer exists in DB, fallback to default profile
      final defProfile = await _ref.read(profileRepositoryProvider).getDefaultProfile();
      if (defProfile != null) {
        state = defProfile.id;
        await prefs.setString(_keyActiveProfileId, defProfile.id);
      }
    } catch (e) {
      debugPrint('Error loading active profile ID: $e');
    }
  }

  Future<void> setActiveProfileId(String id, {bool force = false}) async {
    if (!force && state == id) return;
    state = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyActiveProfileId, id);

      // Check if profile exists and synchronize its currency
      final profile = await _ref.read(profileRepositoryProvider).getProfileById(id);
      if (profile != null) {
        final currencyCode = profile.currency;
        final matchedCurrency = supportedCurrencies.firstWhere(
          (c) => c.code == currencyCode,
          orElse: () => supportedCurrencies.first,
        );
        await _ref.read(currencyProvider.notifier).setCurrency(matchedCurrency);
      }
    } catch (e) {
      debugPrint('Error persisting active profile: $e');
    }
  }

  Future<void> checkAndFallbackIfDeleted(List<UserProfile> currentProfiles) async {
    if (currentProfiles.isNotEmpty && !currentProfiles.any((p) => p.id == state)) {
      final fallback = currentProfiles.firstWhere((p) => p.isDefault, orElse: () => currentProfiles.first);
      await setActiveProfileId(fallback.id, force: true);
    }
  }
}

final activeProfileIdProvider = StateNotifierProvider<ActiveProfileNotifier, String>((ref) {
  return ActiveProfileNotifier(ref);
});

final allProfilesProvider = StreamProvider<List<UserProfile>>((ref) {
  return ref.watch(profileRepositoryProvider).watchAllProfiles();
});

final activeProfileProvider = Provider<UserProfile?>((ref) {
  final activeId = ref.watch(activeProfileIdProvider);
  final allProfilesAsync = ref.watch(allProfilesProvider);

  return allProfilesAsync.when(
    data: (profiles) {
      if (profiles.isEmpty) return null;
      return profiles.firstWhere(
        (p) => p.id == activeId,
        orElse: () => profiles.first,
      );
    },
    loading: () => null,
    error: (error, stack) => null,
  );
});
