import 'package:framelean/domain/value_objects/app_update_package_info.dart';

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.buildNumber,
    required this.channel,
    required this.platform,
    required this.mandatory,
    required this.minSupportedBuild,
    required this.notesUrl,
    required this.releaseNotesMarkdown,
    required this.releaseNotesSummary,
    required this.package,
    this.githubDownloadUrl,
    this.giteeDownloadUrl,
    this.backupDownloadUrl,
  });

  final String version;
  final int buildNumber;
  final String channel;
  final String platform;
  final bool mandatory;
  final int minSupportedBuild;
  final String notesUrl;
  final String releaseNotesMarkdown;
  final String releaseNotesSummary;
  final AppUpdatePackageInfo package;
  final String? githubDownloadUrl;
  final String? giteeDownloadUrl;
  final String? backupDownloadUrl;

  bool get hasExternalDownloadLinks =>
      _hasText(githubDownloadUrl) ||
      _hasText(giteeDownloadUrl) ||
      _hasText(backupDownloadUrl);

  bool get hasPackageDownloadMetadata => package.hasDownloadMetadata;

  String get notificationDedupeKey => 'update:$platform:$version:$buildNumber';
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
