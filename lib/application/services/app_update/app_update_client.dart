import 'package:framelean/domain/value_objects/app_release_info.dart';
import 'package:framelean/domain/value_objects/app_release_notes.dart';
import 'package:framelean/domain/value_objects/app_update_package_info.dart';

class AppUpdateCheckResult {
  const AppUpdateCheckResult({required this.updateAvailable, this.release});

  final bool updateAvailable;
  final AppReleaseInfo? release;
}

class AppUpdateDownloadTicket {
  const AppUpdateDownloadTicket({
    required this.downloadUrl,
    required this.expiresAt,
    required this.package,
  });

  final Uri downloadUrl;
  final DateTime expiresAt;
  final AppUpdatePackageInfo package;
}

abstract class AppUpdateClient {
  Future<AppUpdateCheckResult> checkForUpdate({
    required String currentVersion,
    required int currentBuild,
    required String platform,
    required String channel,
  });

  Future<AppUpdateDownloadTicket> createDownloadTicket({
    required AppReleaseInfo release,
    required String installId,
  });

  Future<String> loadReleaseNotes(AppReleaseInfo release);

  Future<List<AppReleaseNotes>> loadReleaseNotesList({required String channel});
}
