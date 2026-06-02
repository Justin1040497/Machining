import 'package:framelean/application/services/update/app_version.dart';

enum AppUpdatePlatform {
  macosArm64;

  String get updateApiValue {
    return switch (this) {
      AppUpdatePlatform.macosArm64 => 'macos-arm64',
    };
  }
}

class AppUpdateAsset {
  const AppUpdateAsset({
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
    this.sha256,
  });

  final String name;
  final Uri downloadUrl;
  final int? sizeBytes;
  final String? sha256;
}

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.version,
    required this.title,
    required this.releaseNotes,
    required this.releasePageUrl,
    required this.packageAsset,
    this.checksumAsset,
  });

  final AppVersion version;
  final String title;
  final String releaseNotes;
  final Uri releasePageUrl;
  final AppUpdateAsset packageAsset;
  final AppUpdateAsset? checksumAsset;
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.currentVersion,
    required this.latestRelease,
  });

  final AppVersion currentVersion;
  final AppUpdateRelease latestRelease;

  bool get updateAvailable => latestRelease.version > currentVersion;
}

abstract interface class AppUpdateChecker {
  Future<AppUpdateCheckResult> checkForUpdates({
    required AppVersion currentVersion,
    required AppUpdatePlatform platform,
  });
}

class AppUpdateException implements Exception {
  const AppUpdateException(
    this.technicalDetail, {
    this.userMessage = '暂时无法检查更新，请稍后重试',
  });

  final String technicalDetail;
  final String userMessage;

  String get message => technicalDetail;

  @override
  String toString() => technicalDetail;
}
