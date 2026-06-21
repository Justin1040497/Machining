import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/app/providers/app_notification_provider.dart';
import 'package:framelean/app/providers/app_update_provider.dart';
import 'package:framelean/app/providers/platform_provider.dart';
import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/application/services/app_notifications/app_notification_manager.dart';
import 'package:framelean/application/services/app_update/app_update_client.dart';
import 'package:framelean/application/services/app_update/app_update_download_state_store.dart';
import 'package:framelean/application/services/app_update/app_update_install_id_store.dart';
import 'package:framelean/application/services/app_update/app_update_package_downloader.dart';
import 'package:framelean/application/services/app_update/enterprise_update_config_store.dart';
import 'package:framelean/application/services/app_update/sparkle_update_controller.dart';
import 'package:framelean/application/services/app_update/updater_helper_launcher.dart';
import 'package:framelean/application/services/platform/file_revealer.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/app_update_status.dart';
import 'package:framelean/domain/value_objects/app_release_info.dart';
import 'package:framelean/domain/value_objects/app_release_notes.dart';
import 'package:framelean/domain/value_objects/app_update_package_info.dart';
import 'package:framelean/domain/value_objects/enterprise_update_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'automatic check exposes available update and upserts notification',
    () async {
      final fixture = appUpdateFixture();
      addTearDown(fixture.dispose);

      await fixture.container.read(appUpdateProvider.future);
      await pumpEventQueue();

      final state = fixture.container.read(appUpdateProvider).requireValue;
      expect(state.status, AppUpdateStatus.available);
      expect(state.release?.version, testRelease.version);
      expect(fixture.client.checkCount, 1);
      expect(fixture.notifications.notifications, hasLength(1));
      expect(
        fixture.notifications.notifications.single.dedupeKey,
        testRelease.notificationDedupeKey,
      );
    },
  );

  test('download creates ticket and reaches downloaded state', () async {
    final fixture = appUpdateFixture();
    addTearDown(fixture.dispose);
    await fixture.container.read(appUpdateProvider.future);
    await pumpEventQueue();

    await fixture.container
        .read(appUpdateProvider.notifier)
        .startOrResumeDownload();

    final state = fixture.container.read(appUpdateProvider).requireValue;
    expect(state.status, AppUpdateStatus.downloaded);
    expect(state.progress, 1);
    expect(state.downloadedFilePath, '/tmp/FrameLean-v1.2.2-setup.exe');
    expect(fixture.client.ticketRequests.single.installId, 'install-id-1');
    expect(fixture.client.ticketRequests.single.release.version, '1.2.2');
    expect(fixture.downloader.downloadedVersions, ['1.2.2']);
    expect(fixture.downloader.downloadedPlatforms, ['windows-installer']);
    expect(fixture.notifications.notifications.single.title, '更新已下载');
  });

  test('install downloaded update launches helper request', () async {
    final fixture = appUpdateFixture();
    addTearDown(fixture.dispose);
    await fixture.container.read(appUpdateProvider.future);
    await pumpEventQueue();
    await fixture.container
        .read(appUpdateProvider.notifier)
        .startOrResumeDownload();

    await fixture.container
        .read(appUpdateProvider.notifier)
        .installDownloadedUpdate();

    final state = fixture.container.read(appUpdateProvider).requireValue;
    expect(state.status, AppUpdateStatus.installing);
    expect(fixture.launcher.requests, hasLength(1));
    expect(fixture.launcher.requests.single.release.version, '1.2.2');
    expect(fixture.restartPreparation.calls, 1);
    expect(fixture.launcher.preparationCallsAtLaunch, 1);
    expect(
      fixture.launcher.requests.single.installerPath,
      '/tmp/FrameLean-v1.2.2-setup.exe',
    );
  });

  test('macOS update check uses JSON release service by default', () async {
    final fixture = appUpdateFixture(
      platform: 'macos-universal2',
      release: testMacosRelease,
      downloadedFilePath: '/Users/test/Downloads/FrameLean-v1.2.2.dmg',
    );
    addTearDown(fixture.dispose);

    await fixture.container.read(appUpdateProvider.future);
    await pumpEventQueue();

    final state = fixture.container.read(appUpdateProvider).requireValue;
    expect(state.status, AppUpdateStatus.available);
    expect(state.release?.platform, 'macos-universal2');
    expect(fixture.client.checkedPlatforms, ['macos-universal2']);
  });

  test('macOS downloaded update reveals DMG without restart helper', () async {
    final fixture = appUpdateFixture(
      platform: 'macos-universal2',
      release: testMacosRelease,
      downloadedFilePath: '/Users/test/Downloads/FrameLean-v1.2.2.dmg',
    );
    addTearDown(fixture.dispose);
    await fixture.container.read(appUpdateProvider.future);
    await pumpEventQueue();
    await fixture.container
        .read(appUpdateProvider.notifier)
        .startOrResumeDownload();

    await fixture.container
        .read(appUpdateProvider.notifier)
        .installDownloadedUpdate();

    final state = fixture.container.read(appUpdateProvider).requireValue;
    expect(state.status, AppUpdateStatus.downloaded);
    expect(fixture.revealer.paths, [
      '/Users/test/Downloads/FrameLean-v1.2.2.dmg',
    ]);
    expect(fixture.launcher.requests, isEmpty);
    expect(fixture.restartPreparation.calls, 0);
    expect(fixture.notifications.notifications.single.title, 'DMG 已下载');
  });

  test(
    'macOS startup configures Sparkle without an explicit update check',
    () async {
      final sparkle = FakeSparkleUpdateController();
      final config = EnterpriseUpdateConfig.bundled().copyWith(
        macosAppcastUrl: 'https://updates.example.com/api/v1/sparkle/appcast',
      );
      final container = ProviderContainer.test(
        overrides: [
          useSparkleUpdateProvider.overrideWithValue(true),
          enterpriseUpdateConfigCacheProvider.overrideWithValue(
            EnterpriseUpdateConfigCache(StaticUpdateConfigStore(config)),
          ),
          sparkleUpdateControllerProvider.overrideWithValue(sparkle),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appUpdateProvider.future);
      await pumpEventQueue();

      expect(sparkle.policyStatusRequests, hasLength(1));
      expect(sparkle.informationChecks, isEmpty);
      expect(sparkle.userChecks, isEmpty);

      await container.read(appUpdateProvider.notifier).checkForUpdate();
      expect(sparkle.userChecks, hasLength(1));
    },
  );
}

AppUpdateFixture appUpdateFixture({
  String platform = 'windows-installer',
  AppReleaseInfo release = testRelease,
  String downloadedFilePath = '/tmp/FrameLean-v1.2.2-setup.exe',
  FakeAppUpdateDownloadStateStore? downloadStateStore,
}) {
  final client = FakeAppUpdateClient(release);
  final downloader = FakeAppUpdatePackageDownloader(downloadedFilePath);
  final installIdStore = const FakeAppUpdateInstallIdStore();
  final stateStore = downloadStateStore ?? FakeAppUpdateDownloadStateStore();
  final restartPreparation = RecordingRestartPreparation();
  final launcher = FakeUpdaterHelperLauncher(restartPreparation);
  final revealer = FakeFileRevealer();
  final notifications = RecordingNotificationRepository();
  final notificationManager = AppNotificationManager(
    repository: notifications,
    readSettings: () async => AppSettings.initial(),
  );
  final container = ProviderContainer.test(
    overrides: [
      appUpdateClientProvider.overrideWithValue(client),
      appUpdateDownloaderProvider.overrideWithValue(downloader),
      appUpdateInstallIdStoreProvider.overrideWithValue(installIdStore),
      appUpdateDownloadStateStoreProvider.overrideWithValue(stateStore),
      updaterHelperLauncherProvider.overrideWithValue(launcher),
      fileRevealerProvider.overrideWithValue(revealer),
      updateRestartPreparationProvider.overrideWithValue(
        restartPreparation.call,
      ),
      useSparkleUpdateProvider.overrideWithValue(false),
      currentUpdatePlatformProvider.overrideWithValue(platform),
      appNotificationRepositoryProvider.overrideWithValue(notifications),
      appNotificationManagerProvider.overrideWithValue(notificationManager),
    ],
  );
  return AppUpdateFixture(
    container: container,
    client: client,
    downloader: downloader,
    launcher: launcher,
    revealer: revealer,
    restartPreparation: restartPreparation,
    notifications: notifications,
    notificationManager: notificationManager,
  );
}

const testRelease = AppReleaseInfo(
  version: '1.2.2',
  buildNumber: 6,
  channel: 'stable',
  platform: 'windows-installer',
  mandatory: false,
  minSupportedBuild: 0,
  notesUrl: '/api/v1/releases/1.2.2/notes',
  releaseNotesMarkdown: '# FrameLean v1.2.2\n\n- 更新体验优化',
  releaseNotesSummary: '更新体验优化',
  package: AppUpdatePackageInfo(
    fileName: 'FrameLean-v1.2.2-windows-x64-setup.exe',
    sizeBytes: 100,
    sha256: 'a',
  ),
);

const testMacosRelease = AppReleaseInfo(
  version: '1.2.2',
  buildNumber: 6,
  channel: 'stable',
  platform: 'macos-universal2',
  mandatory: false,
  minSupportedBuild: 0,
  notesUrl: '/api/v1/releases/1.2.2/notes',
  releaseNotesMarkdown: '# FrameLean v1.2.2\n\n- 更新体验优化',
  releaseNotesSummary: '更新体验优化',
  package: AppUpdatePackageInfo(
    fileName: 'FrameLean-v1.2.2-macos-universal2.dmg',
    sizeBytes: 100,
    sha256: 'a',
  ),
);

class AppUpdateFixture {
  const AppUpdateFixture({
    required this.container,
    required this.client,
    required this.downloader,
    required this.launcher,
    required this.revealer,
    required this.restartPreparation,
    required this.notifications,
    required this.notificationManager,
  });

  final ProviderContainer container;
  final FakeAppUpdateClient client;
  final FakeAppUpdatePackageDownloader downloader;
  final FakeUpdaterHelperLauncher launcher;
  final FakeFileRevealer revealer;
  final RecordingRestartPreparation restartPreparation;
  final RecordingNotificationRepository notifications;
  final AppNotificationManager notificationManager;

  void dispose() {
    notificationManager.dispose();
    notifications.dispose();
    container.dispose();
  }
}

class FakeAppUpdateClient implements AppUpdateClient {
  FakeAppUpdateClient(this.release);

  final AppReleaseInfo release;
  int checkCount = 0;
  final List<String> checkedPlatforms = [];
  final List<TicketRequest> ticketRequests = [];

  @override
  Future<AppUpdateCheckResult> checkForUpdate({
    required String currentVersion,
    required int currentBuild,
    required String platform,
    required String channel,
  }) async {
    checkCount += 1;
    checkedPlatforms.add(platform);
    return AppUpdateCheckResult(updateAvailable: true, release: release);
  }

  @override
  Future<AppUpdateDownloadTicket> createDownloadTicket({
    required AppReleaseInfo release,
    required String installId,
  }) async {
    ticketRequests.add(TicketRequest(release: release, installId: installId));
    return AppUpdateDownloadTicket(
      downloadUrl: Uri.parse('https://framelean.example/download'),
      expiresAt: DateTime(2026, 6, 18, 12),
      package: release.package,
    );
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

class TicketRequest {
  const TicketRequest({required this.release, required this.installId});

  final AppReleaseInfo release;
  final String installId;
}

class FakeAppUpdatePackageDownloader implements AppUpdatePackageDownloader {
  FakeAppUpdatePackageDownloader(this.filePath);

  final String filePath;
  final List<String> downloadedVersions = [];
  final List<String> downloadedPlatforms = [];
  String? existingPackagePath;

  @override
  Future<String?> findExistingValidPackage({
    required AppUpdatePackageInfo package,
    required String version,
    required String platform,
  }) async {
    return existingPackagePath;
  }

  @override
  Future<AppUpdateDownloadResult> download({
    required AppUpdateDownloadTicket ticket,
    required String version,
    required String platform,
    required AppUpdateDownloadCancellationToken cancellationToken,
    required AppUpdateDownloadProgressCallback onProgress,
  }) async {
    downloadedVersions.add(version);
    downloadedPlatforms.add(platform);
    onProgress(25, ticket.package.sizeBytes);
    onProgress(ticket.package.sizeBytes, ticket.package.sizeBytes);
    return AppUpdateDownloadResult(filePath: filePath);
  }
}

class FakeFileRevealer implements FileRevealer {
  final List<String> paths = [];

  @override
  Future<FileRevealResult> revealPath(String targetPath) async {
    paths.add(targetPath);
    return const FileRevealResult.success();
  }
}

class FakeAppUpdateInstallIdStore implements AppUpdateInstallIdStore {
  const FakeAppUpdateInstallIdStore();

  @override
  Future<String> loadOrCreateInstallId() async {
    return 'install-id-1';
  }
}

class RecordingRestartPreparation {
  int calls = 0;

  Future<void> call() async {
    calls += 1;
  }
}

class FakeUpdaterHelperLauncher implements UpdaterHelperLauncher {
  FakeUpdaterHelperLauncher(this.restartPreparation);

  final RecordingRestartPreparation restartPreparation;
  final List<UpdaterHelperLaunchRequest> requests = [];
  int preparationCallsAtLaunch = 0;

  @override
  Future<void> launch(UpdaterHelperLaunchRequest request) async {
    preparationCallsAtLaunch = restartPreparation.calls;
    requests.add(request);
  }
}

class StaticUpdateConfigStore implements EnterpriseUpdateConfigStore {
  const StaticUpdateConfigStore(this.config);

  final EnterpriseUpdateConfig config;

  @override
  Future<EnterpriseUpdateConfig> load() async => config;
}

class FakeSparkleUpdateController implements SparkleUpdateController {
  final List<EnterpriseUpdateConfig> userChecks = [];
  final List<EnterpriseUpdateConfig> informationChecks = [];
  final List<EnterpriseUpdateConfig> policyStatusRequests = [];

  @override
  Future<void> checkForUpdates(EnterpriseUpdateConfig config) async {
    userChecks.add(config);
  }

  @override
  Future<void> checkForUpdateInformation(EnterpriseUpdateConfig config) async {
    informationChecks.add(config);
  }

  @override
  Future<SparkleUpdatePolicyStatus> getUpdatePolicyStatus(
    EnterpriseUpdateConfig config,
  ) async {
    policyStatusRequests.add(config);
    return SparkleUpdatePolicyStatus(
      available: true,
      automaticChecksEnabled: config.allowAutomaticChecks,
      appcastUrl: config.macosAppcastUrl,
    );
  }
}

class FakeAppUpdateDownloadStateStore implements AppUpdateDownloadStateStore {
  PersistedDownloadState? _state;

  @override
  Future<PersistedDownloadState?> load() async => _state;

  @override
  Future<void> save(PersistedDownloadState state) async {
    _state = state;
  }

  @override
  Future<void> clear() async {
    _state = null;
  }
}

class RecordingNotificationRepository implements AppNotificationRepository {
  final StreamController<List<AppNotificationEntry>> _controller =
      StreamController<List<AppNotificationEntry>>.broadcast();
  final List<AppNotificationEntry> notifications = [];

  void dispose() {
    unawaited(_controller.close());
  }

  void _emit() {
    _controller.add(List.unmodifiable(notifications));
  }

  @override
  Future<void> saveNotification(AppNotificationEntry notification) async {
    notifications.insert(0, notification);
    _emit();
  }

  @override
  Future<AppNotificationEntry> upsertNotificationByDedupeKey(
    AppNotificationEntry notification,
  ) async {
    notifications.removeWhere(
      (item) =>
          item.dedupeKey != null && item.dedupeKey == notification.dedupeKey,
    );
    notifications.insert(0, notification);
    _emit();
    return notification;
  }

  @override
  Future<List<AppNotificationEntry>> loadRecentNotifications({
    int? limit,
  }) async {
    return notifications.take(limit ?? notifications.length).toList();
  }

  @override
  Stream<List<AppNotificationEntry>> watchRecentNotifications({int? limit}) {
    return _controller.stream.map(
      (items) => items.take(limit ?? items.length).toList(),
    );
  }

  @override
  Future<void> markAsRead(String id, DateTime readAt) async {}

  @override
  Future<void> markAllAsRead(DateTime readAt) async {}

  @override
  Future<void> dismiss(String id, DateTime dismissedAt) async {}

  @override
  Future<void> dismissAll(DateTime dismissedAt) async {}
}
