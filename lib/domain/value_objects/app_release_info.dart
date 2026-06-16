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

  String get notificationDedupeKey => 'update:$platform:$version:$buildNumber';
}
