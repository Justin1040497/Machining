import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/services/app_update/app_update_client.dart';
import 'package:framelean/application/services/app_update/app_update_download_state_store.dart';
import 'package:framelean/application/services/app_update/enterprise_update_config_store.dart';
import 'package:framelean/application/services/app_update/app_update_install_id_store.dart';
import 'package:framelean/application/services/app_update/app_update_package_downloader.dart';
import 'package:framelean/application/services/app_update/release_signature_verifier.dart';
import 'package:framelean/application/services/app_update/sparkle_update_controller.dart';
import 'package:framelean/application/services/app_update/updater_helper_launcher.dart';
import 'package:framelean/application/services/framelean_build_info.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/domain/enums/app_update_status.dart';
import 'package:framelean/domain/value_objects/enterprise_update_config.dart';
import 'package:framelean/domain/value_objects/app_release_info.dart';
import 'package:framelean/domain/value_objects/app_release_notes.dart';
import 'package:framelean/domain/value_objects/app_update_state.dart';
import 'package:framelean/infrastructure/services/app_update/cryptography_release_signature_verifier.dart';
import 'package:framelean/infrastructure/services/app_update/enterprise_aware_app_update_client.dart';
import 'package:framelean/infrastructure/services/app_update/local_app_update_download_state_store.dart';
import 'package:framelean/infrastructure/services/app_update/local_app_update_install_id_store.dart';
import 'package:framelean/infrastructure/services/app_update/local_app_update_package_downloader.dart';
import 'package:framelean/infrastructure/services/app_update/local_enterprise_update_config_store.dart';
import 'package:framelean/infrastructure/services/app_update/local_updater_helper_launcher.dart';
import 'package:framelean/infrastructure/services/app_update/method_channel_sparkle_update_controller.dart';
import 'package:framelean/app/constants.dart';
import 'package:framelean/app/providers/app_notification_provider.dart';
import 'package:framelean/app/providers/execution_provider.dart';
import 'package:framelean/app/providers/platform_provider.dart';

typedef UpdateRestartPreparation = Future<void> Function();

final updateRestartPreparationProvider = Provider<UpdateRestartPreparation>((
  ref,
) {
  return () async {
    final runner = ref.read(ffmpegTaskQueueRunnerProvider);
    await runner.pauseAllRunningTasks();
    await runner.cancelAllExecutions();
  };
});

const _defaultUpdateChannel = String.fromEnvironment(
  'FRAMELEAN_UPDATE_CHANNEL',
  defaultValue: defaultUpdateChannelKey,
);
const _useSparkleUpdates = bool.fromEnvironment(
  'FRAMELEAN_USE_SPARKLE_UPDATES',
  defaultValue: false,
);
final enterpriseUpdateConfigStoreProvider =
    Provider<EnterpriseUpdateConfigStore>((ref) {
      return const LocalEnterpriseUpdateConfigStore();
    });

final enterpriseUpdateConfigCacheProvider =
    Provider<EnterpriseUpdateConfigCache>((ref) {
      return EnterpriseUpdateConfigCache(
        ref.watch(enterpriseUpdateConfigStoreProvider),
      );
    });

final releaseSignatureVerifierProvider = Provider<ReleaseSignatureVerifier>((
  ref,
) {
  return CryptographyReleaseSignatureVerifier();
});

final sparkleUpdateControllerProvider = Provider<SparkleUpdateController>((
  ref,
) {
  final controller = MethodChannelSparkleUpdateController();
  controller.setRestartPreparationHandler(
    ref.read(updateRestartPreparationProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final useSparkleUpdateProvider = Provider<bool>((ref) {
  return Platform.isMacOS && _useSparkleUpdates;
});

final currentUpdatePlatformProvider = Provider<String>((ref) {
  return _currentUpdatePlatform();
});

final isManualMacosUpdateProvider = Provider<bool>((ref) {
  return ref.watch(currentUpdatePlatformProvider) == macosUpdatePlatform &&
      !ref.watch(useSparkleUpdateProvider);
});

final appUpdateClientProvider = Provider<AppUpdateClient>((ref) {
  final client = EnterpriseAwareAppUpdateClient(
    configCache: ref.watch(enterpriseUpdateConfigCacheProvider),
  );
  ref.onDispose(client.httpClient.close);
  return client;
});

final appUpdateDownloaderProvider = Provider<AppUpdatePackageDownloader>((ref) {
  final downloader = LocalAppUpdatePackageDownloader(
    configCache: ref.watch(enterpriseUpdateConfigCacheProvider),
    signatureVerifier: ref.watch(releaseSignatureVerifierProvider),
  );
  ref.onDispose(downloader.httpClient.close);
  return downloader;
});

final appUpdateInstallIdStoreProvider = Provider<AppUpdateInstallIdStore>((
  ref,
) {
  return const LocalAppUpdateInstallIdStore();
});

final appUpdateDownloadStateStoreProvider =
    Provider<AppUpdateDownloadStateStore>((ref) {
      return const LocalAppUpdateDownloadStateStore();
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
  final config = await ref.watch(enterpriseUpdateConfigCacheProvider).load();
  final notes = await ref
      .watch(appUpdateClientProvider)
      .loadReleaseNotesList(
        channel: config.channel.isEmpty
            ? _defaultUpdateChannel
            : config.channel,
      );
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
    await ref.read(enterpriseUpdateConfigCacheProvider).load();

    final restored = await _tryRestorePersistedDownload();

    if (!_autoCheckStarted) {
      _autoCheckStarted = true;
      scheduleMicrotask(() {
        unawaited(checkForUpdate(automatic: true));
      });
    }
    ref.onDispose(() {
      _downloadCancellationToken?.cancel();
    });
    return restored ?? AppUpdateState.initial();
  }

  Future<AppUpdateState?> _tryRestorePersistedDownload() async {
    final store = ref.read(appUpdateDownloadStateStoreProvider);
    final persisted = await store.load();
    if (persisted == null) {
      return null;
    }

    final file = File(persisted.filePath);
    if (!await file.exists()) {
      await store.clear();
      return null;
    }

    try {
      final digest = await sha256.bind(file.openRead()).first;
      final actual = digest.toString().toLowerCase();
      if (actual != persisted.release.package.sha256.toLowerCase()) {
        await store.clear();
        return null;
      }
    } on Object {
      await store.clear();
      return null;
    }

    return AppUpdateState(
      status: AppUpdateStatus.downloaded,
      release: persisted.release,
      progress: 1,
      downloadedFilePath: persisted.filePath,
    );
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
      final config = await ref.read(enterpriseUpdateConfigCacheProvider).load();
      if (ref.read(useSparkleUpdateProvider)) {
        await _checkForMacosSparkleUpdate(config, current, automatic);
        return;
      }
      final result = await ref
          .read(appUpdateClientProvider)
          .checkForUpdate(
            currentVersion: FrameLeanBuildInfo.currentVersionLabel,
            currentBuild: FrameLeanBuildInfo.currentBuildNumber,
            platform: ref.read(currentUpdatePlatformProvider),
            channel: config.channel.isEmpty
                ? _defaultUpdateChannel
                : config.channel,
          );

      if (!result.updateAvailable || result.release == null) {
        await ref.read(appUpdateDownloadStateStoreProvider).clear();
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
                source: notificationSourceUpdate,
              );
        }
        return;
      }

      // Check whether a valid package already exists in the download
      // directory so we can skip re-downloading.
      final existingPath = await ref
          .read(appUpdateDownloaderProvider)
          .findExistingValidPackage(
            package: result.release!.package,
            version: result.release!.version,
            platform: result.release!.platform,
          );

      if (existingPath != null) {
        await ref.read(appUpdateDownloadStateStoreProvider).save(
              PersistedDownloadState(
                release: result.release!,
                filePath: existingPath,
              ),
            );
        state = AsyncData(
          AppUpdateState(
            status: AppUpdateStatus.downloaded,
            release: result.release,
            progress: 1,
            downloadedFilePath: existingPath,
            checkedAt: DateTime.now(),
          ),
        );
        await ref
            .read(appNotificationManagerProvider)
            .updateUpdateNotification(
              release: result.release!,
              status: AppUpdateStatus.downloaded,
              title: 'DMG 已下载',
              level: AppNotificationLevel.success,
            );
        return;
      }

      // Clear persisted state if the new version differs from the
      // previously downloaded one.
      if (current.downloadedFilePath != null &&
          current.release?.version != result.release!.version) {
        await ref.read(appUpdateDownloadStateStoreProvider).clear();
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
              source: notificationSourceUpdate,
            );
      }
    }
  }

  Future<void> refreshPlatformUpdatePolicy() async {
    if (!ref.read(useSparkleUpdateProvider)) {
      return;
    }
    final config = await ref.read(enterpriseUpdateConfigCacheProvider).load();
    final sparkleConfig = _withResolvedMacosAppcastUrl(config);
    await ref
        .read(sparkleUpdateControllerProvider)
        .getUpdatePolicyStatus(
          sparkleConfig.updatesDisabled
              ? sparkleConfig.copyWith(
                  allowAutomaticChecks: false,
                  allowInAppInstall: false,
                )
              : sparkleConfig,
        );
  }

  Future<void> startOrResumeDownload() async {
    if (ref.read(useSparkleUpdateProvider)) {
      await checkForUpdate();
      return;
    }
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
      await ref.read(appUpdateDownloadStateStoreProvider).save(
            PersistedDownloadState(
              release: release,
              filePath: result.filePath,
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
            source: notificationSourceUpdate,
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
    if (ref.read(useSparkleUpdateProvider)) {
      await checkForUpdate();
      return;
    }
    final current = state.asData?.value;
    final release = current?.release;
    final installerPath = current?.downloadedFilePath;
    if (current == null ||
        release == null ||
        installerPath == null ||
        current.status != AppUpdateStatus.downloaded) {
      return;
    }

    if (release.platform == macosUpdatePlatform) {
      await _revealDownloadedMacosDmg(current, release, installerPath);
      return;
    }

    state = AsyncData(current.copyWith(status: AppUpdateStatus.installing));
    try {
      await ref.read(updateRestartPreparationProvider)();
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
            source: notificationSourceUpdate,
          );
    }
  }

  Future<void> _revealDownloadedMacosDmg(
    AppUpdateState current,
    AppReleaseInfo release,
    String installerPath,
  ) async {
    final result = await ref
        .read(fileRevealerProvider)
        .revealPath(installerPath);
    if (result.succeeded) {
      state = AsyncData(
        current.copyWith(
          status: AppUpdateStatus.downloaded,
          progress: 1,
          downloadedFilePath: installerPath,
          errorMessage: null,
        ),
      );
      await ref
          .read(appNotificationManagerProvider)
          .updateUpdateNotification(
            release: release,
            status: AppUpdateStatus.downloaded,
            title: 'DMG 已下载',
            level: AppNotificationLevel.success,
          );
      return;
    }

    final message = result.message ?? '打开 DMG 所在位置失败';
    state = AsyncData(
      current.copyWith(status: AppUpdateStatus.failed, errorMessage: message),
    );
    await ref
        .read(appNotificationManagerProvider)
        .notify(
          level: AppNotificationLevel.error,
          title: '打开 DMG 失败',
          message: message,
          source: notificationSourceUpdate,
        );
  }

  Future<void> _checkForMacosSparkleUpdate(
    EnterpriseUpdateConfig config,
    AppUpdateState previous,
    bool automatic,
  ) async {
    final sparkleConfig = _withResolvedMacosAppcastUrl(config);
    if (sparkleConfig.updatesDisabled ||
        (!sparkleConfig.hasMacosAppcastUrl &&
            !sparkleConfig.hasUpdateBaseUrl)) {
      await ref
          .read(sparkleUpdateControllerProvider)
          .getUpdatePolicyStatus(
            sparkleConfig.copyWith(
              allowAutomaticChecks: false,
              allowInAppInstall: false,
            ),
          );
      state = AsyncData(
        previous.copyWith(status: AppUpdateStatus.idle, errorMessage: null),
      );
      return;
    }

    if (automatic) {
      await ref
          .read(sparkleUpdateControllerProvider)
          .getUpdatePolicyStatus(sparkleConfig);
    } else {
      await ref
          .read(sparkleUpdateControllerProvider)
          .checkForUpdates(sparkleConfig);
    }
    state = AsyncData(
      previous.copyWith(status: AppUpdateStatus.idle, errorMessage: null),
    );
  }
}

EnterpriseUpdateConfig _withResolvedMacosAppcastUrl(
  EnterpriseUpdateConfig config,
) {
  if (config.hasMacosAppcastUrl || !config.hasUpdateBaseUrl) {
    return config;
  }
  final base = Uri.parse(config.updateBaseUrl);
  final basePath = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  final channel = config.channel.isEmpty
      ? _defaultUpdateChannel
      : config.channel;
  return config.copyWith(
    macosAppcastUrl: base
        .replace(
          path: '$basePath$sparkleAppcastApiPath',
          queryParameters: {'channel': channel},
        )
        .toString(),
  );
}

String _currentUpdatePlatform() {
  if (Platform.isWindows) {
    return windowsUpdatePlatform;
  }
  if (Platform.isMacOS) {
    return macosUpdatePlatform;
  }
  if (Platform.isLinux) {
    return linuxUpdatePlatform;
  }
  return unknownUpdatePlatform;
}
