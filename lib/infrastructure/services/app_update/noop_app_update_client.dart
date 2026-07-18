import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';

class NoopAppUpdateClient implements AppUpdateClient {
  const NoopAppUpdateClient();

  @override
  Future<AppUpdateCheckResult> checkForUpdate({
    required String currentVersion,
    required int currentBuild,
    required String platform,
    required String channel,
  }) async {
    return const AppUpdateCheckResult(updateAvailable: false);
  }

  @override
  Future<AppUpdateDownloadTicket> createDownloadTicket({
    required AppReleaseInfo release,
    required String installId,
  }) {
    throw StateError('未配置更新服务地址');
  }

  @override
  Future<String> loadReleaseNotes(AppReleaseInfo release) async {
    return release.releaseNotesMarkdown;
  }

  @override
  Future<List<AppReleaseNotes>> loadReleaseNotesList({
    required String channel,
  }) async {
    return const [];
  }
}
