import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/services/app_update/app_update_client.dart';
import 'package:framelean/application/services/app_update/app_update_install_id_store.dart';
import 'package:framelean/application/services/app_update/app_update_package_downloader.dart';
import 'package:framelean/application/services/app_update/updater_helper_launcher.dart';
import 'package:framelean/application/services/framelean_build_info.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/domain/enums/app_update_status.dart';
import 'package:framelean/domain/value_objects/app_release_notes.dart';
import 'package:framelean/domain/value_objects/app_update_state.dart';
import 'package:framelean/infrastructure/services/app_update/http_app_update_client.dart';
import 'package:framelean/infrastructure/services/app_update/local_app_update_install_id_store.dart';
import 'package:framelean/infrastructure/services/app_update/local_app_update_package_downloader.dart';
import 'package:framelean/infrastructure/services/app_update/local_updater_helper_launcher.dart';
import 'package:framelean/infrastructure/services/app_update/noop_app_update_client.dart';
import 'package:framelean/app/providers/app_notification_provider.dart';

const _updateBaseUrl = String.fromEnvironment('FRAMELEAN_UPDATE_BASE_URL');
const _updateChannel = String.fromEnvironment(
  'FRAMELEAN_UPDATE_CHANNEL',
  defaultValue: 'stable',
);

final appUpdateClientProvider = Provider<AppUpdateClient>((ref) {
  final trimmedBaseUrl = _updateBaseUrl.trim();
  if (trimmedBaseUrl.isEmpty) {
    return const NoopAppUpdateClient();
  }

  final client = HttpAppUpdateClient(baseUri: Uri.parse(trimmedBaseUrl));
  ref.onDispose(client.httpClient.close);
  return client;
});

final appUpdateDownloaderProvider = Provider<AppUpdatePackageDownloader>((ref) {
  final downloader = LocalAppUpdatePackageDownloader();
  ref.onDispose(downloader.httpClient.close);
  return downloader;
});

final appUpdateInstallIdStoreProvider = Provider<AppUpdateInstallIdStore>((
  ref,
) {
  return const LocalAppUpdateInstallIdStore();
});

final updaterHelperLauncherProvider = Provider<UpdaterHelperLauncher>((ref) {
  return const LocalUpdaterHelperLauncher();
});

final appUpdateProvider =
    AsyncNotifierProvider<AppUpdateNotifier, AppUpdateState>(
      AppUpdateNotifier.new,
    );

final appReleaseNotesProvider = FutureProvider<List<AppReleaseNotes>>((
  ref,
) async {
  final notes = await ref
      .watch(appUpdateClientProvider)
      .loadReleaseNotesList(channel: _updateChannel);
  if (notes.isNotEmpty) {
    return notes;
  }

  final currentUpdate = ref.watch(appUpdateProvider).asData?.value.release;
  if (currentUpdate == null) {
    return const [];
  }

  return [
    AppReleaseNotes(
      version: currentUpdate.version,
      buildNumber: currentUpdate.buildNumber,
      channel: currentUpdate.channel,
      publishedAt: null,
      markdown: currentUpdate.releaseNotesMarkdown,
      summary: currentUpdate.releaseNotesSummary,
    ),
  ];
});

class AppUpdateNotifier extends AsyncNotifier<AppUpdateState> {
  AppUpdateDownloadCancellationToken? _downloadCancellationToken;
  bool _autoCheckStarted = false;

  @override
  Future<AppUpdateState> build() async {
    if (!_autoCheckStarted) {
      _autoCheckStarted = true;
      scheduleMicrotask(() {
        unawaited(checkForUpdate(automatic: true));
      });
    }
    ref.onDispose(() {
      _downloadCancellationToken?.cancel();
    });
    return AppUpdateState.initial();
  }

  Future<void> checkForUpdate({bool automatic = false}) async {
    final current = state.asData?.value ?? AppUpdateState.initial();
    if (current.status == AppUpdateStatus.checking ||
        current.status == AppUpdateStatus.downloading) {
      return;
    }

    state = AsyncData(
      current.copyWith(status: AppUpdateStatus.checking, errorMessage: null),
    );

    try {
      final result = await ref
          .read(appUpdateClientProvider)
          .checkForUpdate(
            currentVersion: FrameLeanBuildInfo.currentVersionLabel,
            currentBuild: FrameLeanBuildInfo.currentBuildNumber,
            platform: _currentUpdatePlatform(),
            channel: _updateChannel,
          );

      if (!result.updateAvailable || result.release == null) {
        state = AsyncData(
          AppUpdateState(
            status: AppUpdateStatus.idle,
            checkedAt: DateTime.now(),
          ),
        );
        if (!automatic) {
          await ref
              .read(appNotificationManagerProvider)
              .notify(
                level: AppNotificationLevel.success,
                title: '已是最新版本',
                source: 'update',
              );
        }
        return;
      }

      final nextState = AppUpdateState(
        status: AppUpdateStatus.available,
        release: result.release,
        checkedAt: DateTime.now(),
      );
      state = AsyncData(nextState);
      await ref
          .read(appNotificationManagerProvider)
          .notifyUpdateAvailable(result.release!);
    } on Object catch (error) {
      final message = error.toString();
      state = AsyncData(
        automatic
            ? current.copyWith(status: AppUpdateStatus.idle, errorMessage: null)
            : current.copyWith(
                status: AppUpdateStatus.failed,
                errorMessage: message,
              ),
      );
      if (!automatic) {
        await ref
            .read(appNotificationManagerProvider)
            .notify(
              level: AppNotificationLevel.error,
              title: '检查更新失败',
              message: message,
              source: 'update',
            );
      }
    }
  }

  Future<void> startOrResumeDownload() async {
    final current = state.asData?.value;
    final release = current?.release;
    if (current == null ||
        release == null ||
        current.status == AppUpdateStatus.downloading) {
      return;
    }

    final cancellationToken = AppUpdateDownloadCancellationToken();
    _downloadCancellationToken = cancellationToken;
    state = AsyncData(
      current.copyWith(status: AppUpdateStatus.downloading, errorMessage: null),
    );
    await ref
        .read(appNotificationManagerProvider)
        .updateUpdateNotification(
          release: release,
          status: AppUpdateStatus.downloading,
          title: '正在下载 ${release.version}',
          level: AppNotificationLevel.warning,
        );

    try {
      final installId = await ref
          .read(appUpdateInstallIdStoreProvider)
          .loadOrCreateInstallId();
      final ticket = await ref
          .read(appUpdateClientProvider)
          .createDownloadTicket(release: release, installId: installId);
      final result = await ref
          .read(appUpdateDownloaderProvider)
          .download(
            ticket: ticket,
            version: release.version,
            platform: release.platform,
            cancellationToken: cancellationToken,
            onProgress: (downloadedBytes, totalBytes) {
              if (state.asData?.value.release?.notificationDedupeKey !=
                  release.notificationDedupeKey) {
                return;
              }
              final progress = totalBytes <= 0
                  ? 0.0
                  : downloadedBytes / totalBytes;
              state = AsyncData(
                (state.asData?.value ?? current).copyWith(
                  status: AppUpdateStatus.downloading,
                  progress: progress.clamp(0, 1),
                ),
              );
            },
          );

      if (cancellationToken.isCancelled) {
        state = AsyncData(
          (state.asData?.value ?? current).copyWith(
            status: AppUpdateStatus.paused,
          ),
        );
        return;
      }

      state = AsyncData(
        (state.asData?.value ?? current).copyWith(
          status: AppUpdateStatus.downloaded,
          progress: 1,
          downloadedFilePath: result.filePath,
        ),
      );
      await ref
          .read(appNotificationManagerProvider)
          .updateUpdateNotification(
            release: release,
            status: AppUpdateStatus.downloaded,
            title: '更新已下载',
            level: AppNotificationLevel.success,
          );
    } on AppUpdateDownloadPausedException {
      state = AsyncData(
        (state.asData?.value ?? current).copyWith(
          status: AppUpdateStatus.paused,
        ),
      );
    } on Object catch (error) {
      state = AsyncData(
        (state.asData?.value ?? current).copyWith(
          status: AppUpdateStatus.failed,
          errorMessage: error.toString(),
        ),
      );
      await ref
          .read(appNotificationManagerProvider)
          .notify(
            level: AppNotificationLevel.error,
            title: '更新下载失败',
            message: error.toString(),
            source: 'update',
          );
    } finally {
      if (identical(_downloadCancellationToken, cancellationToken)) {
        _downloadCancellationToken = null;
      }
    }
  }

  void pauseDownload() {
    _downloadCancellationToken?.cancel();
    final current = state.asData?.value;
    if (current?.status == AppUpdateStatus.downloading) {
      state = AsyncData(current!.copyWith(status: AppUpdateStatus.paused));
    }
  }

  Future<void> installDownloadedUpdate() async {
    final current = state.asData?.value;
    final release = current?.release;
    final installerPath = current?.downloadedFilePath;
    if (current == null ||
        release == null ||
        installerPath == null ||
        current.status != AppUpdateStatus.downloaded) {
      return;
    }

    state = AsyncData(current.copyWith(status: AppUpdateStatus.installing));
    try {
      await ref
          .read(updaterHelperLauncherProvider)
          .launch(
            UpdaterHelperLaunchRequest(
              release: release,
              installerPath: installerPath,
              currentProcessId: pid,
            ),
          );
    } on Object catch (error) {
      state = AsyncData(
        current.copyWith(
          status: AppUpdateStatus.failed,
          errorMessage: error.toString(),
        ),
      );
      await ref
          .read(appNotificationManagerProvider)
          .notify(
            level: AppNotificationLevel.error,
            title: '启动更新助手失败',
            message: error.toString(),
            source: 'update',
          );
    }
  }
}

String _currentUpdatePlatform() {
  if (Platform.isWindows) {
    return 'windows-x64';
  }
  if (Platform.isMacOS) {
    return 'macos-universal2';
  }
  if (Platform.isLinux) {
    return 'linux-x64';
  }
  return 'unknown';
}
