import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Centralized app version details with dynamic platform querying and safe fallbacks.
class AppVersionInfo {
  static const String currentVersion = '1.8.0';
  static const String currentBuildNumber = '9';

  final String version;
  final String buildNumber;

  const AppVersionInfo({
    this.version = currentVersion,
    this.buildNumber = currentBuildNumber,
  });

  String get displayVersion => 'v$version (Build $buildNumber)';
  String get shortVersion => 'v$version';
}

final appVersionProvider = FutureProvider<AppVersionInfo>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return AppVersionInfo(
      version: info.version.isNotEmpty ? info.version : AppVersionInfo.currentVersion,
      buildNumber: info.buildNumber.isNotEmpty ? info.buildNumber : AppVersionInfo.currentBuildNumber,
    );
  } catch (_) {
    return const AppVersionInfo();
  }
});
