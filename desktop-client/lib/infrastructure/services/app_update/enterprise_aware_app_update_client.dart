import 'dart:io';

import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/infrastructure/services/app_update/http_app_update_client.dart';
import 'package:framelean/infrastructure/services/app_update/noop_app_update_client.dart';

class EnterpriseAwareAppUpdateClient implements AppUpdateClient {
  EnterpriseAwareAppUpdateClient({
    required this.configCache,
    HttpClient? httpClient,
  }) : httpClient = httpClient ?? HttpClient();

  final EnterpriseUpdateConfigCache configCache;
  final HttpClient httpClient;

  @override
  Future<AppUpdateCheckResult> checkForUpdate({
    required String currentVersion,
    required int currentBuild,
    required String platform,
    required String channel,
  }) async {
    final config = await configCache.load();
    if (config.updatesDisabled || !config.hasUpdateBaseUrl) {
      return const NoopAppUpdateClient().checkForUpdate(
        currentVersion: currentVersion,
        currentBuild: currentBuild,
        platform: platform,
        channel: channel,
      );
    }
    return _client(config.updateBaseUrl).checkForUpdate(
      currentVersion: currentVersion,
      currentBuild: currentBuild,
      platform: platform,
      channel: config.channel.isEmpty ? channel : config.channel,
    );
  }

  @override
  Future<AppUpdateDownloadTicket> createDownloadTicket({
    required AppReleaseInfo release,
    required String installId,
  }) async {
    final config = await configCache.load();
    if (config.updatesDisabled || !config.hasUpdateBaseUrl) {
      throw StateError('更新已被更新策略禁用');
    }
    return _client(
      config.updateBaseUrl,
    ).createDownloadTicket(release: release, installId: installId);
  }

  @override
  Future<String> loadReleaseNotes(AppReleaseInfo release) async {
    final config = await configCache.load();
    if (config.updatesDisabled || !config.hasUpdateBaseUrl) {
      return release.releaseNotesMarkdown;
    }
    return _client(config.updateBaseUrl).loadReleaseNotes(release);
  }

  @override
  Future<List<AppReleaseNotes>> loadReleaseNotesList({
    required String channel,
  }) async {
    final config = await configCache.load();
    if (config.updatesDisabled || !config.hasUpdateBaseUrl) {
      return const [];
    }
    return _client(config.updateBaseUrl).loadReleaseNotesList(
      channel: config.channel.isEmpty ? channel : config.channel,
    );
  }

  HttpAppUpdateClient _client(String baseUrl) {
    return HttpAppUpdateClient(
      baseUri: Uri.parse(baseUrl),
      httpClient: httpClient,
    );
  }
}
