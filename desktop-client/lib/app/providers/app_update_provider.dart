import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/infrastructure/library.dart';
import 'package:framelean/app/constants.dart';
import 'package:framelean/app/providers/app_notification_provider.dart';
import 'package:framelean/app/providers/execution_provider.dart';
import 'package:framelean/app/providers/platform_provider.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef UpdateRestartPreparation = Future<void> Function();

final updateRestartPreparationProvider = Provider<UpdateRestartPreparation>((
  ref,
) {
  return () async {
    await ref.read(mediaTaskExecutionCoordinatorProvider).pauseActive();
    await ref.read(mediaTaskExecutionCoordinatorProvider).cancelAll();
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

final appUpdateSnoozeStoreProvider = Provider<AppUpdateSnoozeStore>((ref) {
  return const LocalAppUpdateSnoozeStore();
});

/// 开机自启 / 自动检查后是否应该自动弹出更新通知弹窗。
///
/// 由 [AppUpdateNotifier.checkForUpdate] 在 automatic 模式下设置：
/// - 发现新版本且未被 snooze → true
/// - 未发现更新 / 已 snooze / mandatory → false（mandatory 始终弹，由 UI 强制）
/// UI 监听此 provider，true 时弹出 [UpdateNoticeDialog] 并调用
/// [AppUpdateNotifier.consumeAutoNotice] 重置。
final appUpdatePendingAutoNoticeProvider =
    NotifierProvider<AutoNoticeController, bool>(AutoNoticeController.new);

class AutoNoticeController extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

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
    if (!ref.read(appRuntimeEffectsEnabledProvider)) {
      ref.onDispose(() {
        _downloadCancellationToken?.cancel();
      });
      return AppUpdateState.initial();
    }

    await ref.read(enterpriseUpdateConfigCacheProvider).load();

    final restored = await _tryRestorePersistedDownload();

    if (!_autoCheckStarted) {
      _autoCheckStarted = true;
      scheduleMicrotask(() {
        unawaited(checkForUpdate(automatic: true));
      });
      scheduleMicrotask(() {
        unawaited(_checkUpdateFailedSentinel());
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

    if (!persisted.release.hasPackageDownloadMetadata) {
      await store.clear();
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

  Future<void> _checkUpdateFailedSentinel() async {
    File? sentinel;
    try {
      final supportDir = await getApplicationSupportDirectory();
      sentinel = File(p.join(supportDir.path, 'updates', 'update-failed.json'));
      if (!await sentinel.exists()) {
        return;
      }

      final content = await sentinel.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final version = json['version'] as String? ?? '';
      final error = json['error'] as String? ?? '未知错误';
      await sentinel.delete();
      await ref.read(appUpdateDownloadStateStoreProvider).clear();
      await ref
          .read(appNotificationManagerProvider)
          .notify(
            level: AppNotificationLevel.error,
            title: '更新安装失败',
            message: version.isNotEmpty
                ? '版本 $version 安装失败：$error'
                : '安装失败：$error',
            source: notificationSourceUpdate,
          );
    } on Object {
      final file = sentinel;
      if (file == null) {
        return;
      }
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } on Object {
        // best effort
      }
    }
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
        if (automatic) {
          ref.read(appUpdatePendingAutoNoticeProvider.notifier).set(false);
        }
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
        if (automatic) {
          ref.read(appUpdatePendingAutoNoticeProvider.notifier).set(false);
        }
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

      // Sync snooze state: a new published version invalidates any previous
      // snooze for an older version, so the user is naturally re-notified.
      final snoozeStore = ref.read(appUpdateSnoozeStoreProvider);
      final snoozedVersion = await snoozeStore.loadSnoozedVersion();
      if (snoozedVersion != null && snoozedVersion != result.release!.version) {
        await snoozeStore.clearSnoozedVersion();
      }

      // On automatic checks, decide whether to auto-show the notice dialog.
      // Mandatory releases always show (and the dialog is non-dismissable);
      // non-mandatory releases are suppressed only when the user snoozed this
      // exact version.
      if (automatic) {
        final release = result.release!;
        final suppressed =
            !release.mandatory && snoozedVersion == release.version;
        ref.read(appUpdatePendingAutoNoticeProvider.notifier).set(!suppressed);
      }

      final release = result.release!;

      if (!release.hasExternalDownloadLinks &&
          release.hasPackageDownloadMetadata) {
        // Check whether a valid package already exists in the download
        // directory so we can skip re-downloading. Releases that only provide
        // external download links intentionally bypass the retained self-update
        // package flow.
        final existingPath = await ref
            .read(appUpdateDownloaderProvider)
            .findExistingValidPackage(
              package: release.package,
              version: release.version,
              platform: release.platform,
            );

        if (existingPath != null) {
          await ref
              .read(appUpdateDownloadStateStoreProvider)
              .save(
                PersistedDownloadState(
                  release: release,
                  filePath: existingPath,
                ),
              );
          state = AsyncData(
            AppUpdateState(
              status: AppUpdateStatus.downloaded,
              release: release,
              progress: 1,
              downloadedFilePath: existingPath,
              checkedAt: DateTime.now(),
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
      }

      // Clear persisted state if the new version differs from the
      // previously downloaded one.
      if (current.downloadedFilePath != null &&
          current.release?.version != release.version) {
        await ref.read(appUpdateDownloadStateStoreProvider).clear();
      }

      final nextState = AppUpdateState(
        status: AppUpdateStatus.available,
        release: release,
        checkedAt: DateTime.now(),
      );
      state = AsyncData(nextState);
      await ref
          .read(appNotificationManagerProvider)
          .notifyUpdateAvailable(release);
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
      if (automatic) {
        ref.read(appUpdatePendingAutoNoticeProvider.notifier).set(false);
      }
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

  /// Record the current release version as snoozed. The same version will not
  /// auto-show the notice dialog on subsequent automatic checks, but manual
  /// entry points (top-bar chip, settings "check for update") still show it.
  Future<void> snoozeCurrentVersion() async {
    final release = state.asData?.value.release;
    if (release == null) {
      return;
    }
    await ref
        .read(appUpdateSnoozeStoreProvider)
        .saveSnoozedVersion(release.version);
    ref.read(appUpdatePendingAutoNoticeProvider.notifier).set(false);
  }

  /// Called by the UI after it shows the notice dialog in response to
  /// [appUpdatePendingAutoNoticeProvider] turning true. Resets the flag so the
  /// dialog is not shown again until the next automatic check finds an update.
  void consumeAutoNotice() {
    ref.read(appUpdatePendingAutoNoticeProvider.notifier).set(false);
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

    if (release.hasExternalDownloadLinks) {
      await ref
          .read(appNotificationManagerProvider)
          .notify(
            level: AppNotificationLevel.info,
            title: '请在更新弹窗中选择下载地址',
            message: '此版本通过 GitHub、Gitee 或备用地址跳转下载，不再由客户端自动下载安装包。',
            source: notificationSourceUpdate,
          );
      return;
    }

    if (!release.hasPackageDownloadMetadata) {
      state = AsyncData(
        current.copyWith(
          status: AppUpdateStatus.failed,
          errorMessage: '更新包信息不完整，请使用下载地址手动获取新版。',
        ),
      );
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
          .read(appUpdateDownloadStateStoreProvider)
          .save(
            PersistedDownloadState(release: release, filePath: result.filePath),
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
