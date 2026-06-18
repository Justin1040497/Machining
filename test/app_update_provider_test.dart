import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/app/providers/app_notification_provider.dart';
import 'package:framelean/app/providers/app_update_provider.dart';
import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/application/services/app_update/app_update_client.dart';
import 'package:framelean/application/services/app_update/app_update_install_id_store.dart';
import 'package:framelean/application/services/app_update/app_update_package_downloader.dart';
import 'package:framelean/application/services/app_update/updater_helper_launcher.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/enums/app_update_status.dart';
import 'package:framelean/domain/value_objects/app_release_info.dart';
import 'package:framelean/domain/value_objects/app_release_notes.dart';
import 'package:framelean/domain/value_objects/app_update_package_info.dart';

void main() {
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
    expect(fixture.downloader.downloadedPlatforms, ['windows-x64']);
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
    expect(
      fixture.launcher.requests.single.installerPath,
      '/tmp/FrameLean-v1.2.2-setup.exe',
    );
  });
}

AppUpdateFixture appUpdateFixture() {
  final client = FakeAppUpdateClient();
  final downloader = FakeAppUpdatePackageDownloader();
  final installIdStore = const FakeAppUpdateInstallIdStore();
  final launcher = FakeUpdaterHelperLauncher();
  final notifications = RecordingNotificationRepository();
  final container = ProviderContainer.test(
    overrides: [
      appUpdateClientProvider.overrideWithValue(client),
      appUpdateDownloaderProvider.overrideWithValue(downloader),
      appUpdateInstallIdStoreProvider.overrideWithValue(installIdStore),
      updaterHelperLauncherProvider.overrideWithValue(launcher),
      appNotificationRepositoryProvider.overrideWithValue(notifications),
    ],
  );
  return AppUpdateFixture(
    container: container,
    client: client,
    downloader: downloader,
    launcher: launcher,
    notifications: notifications,
  );
}

const testRelease = AppReleaseInfo(
  version: '1.2.2',
  buildNumber: 6,
  channel: 'stable',
  platform: 'windows-x64',
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

class AppUpdateFixture {
  const AppUpdateFixture({
    required this.container,
    required this.client,
    required this.downloader,
    required this.launcher,
    required this.notifications,
  });

  final ProviderContainer container;
  final FakeAppUpdateClient client;
  final FakeAppUpdatePackageDownloader downloader;
  final FakeUpdaterHelperLauncher launcher;
  final RecordingNotificationRepository notifications;

  void dispose() {
    notifications.dispose();
    container.dispose();
  }
}

class FakeAppUpdateClient implements AppUpdateClient {
  int checkCount = 0;
  final List<TicketRequest> ticketRequests = [];

  @override
  Future<AppUpdateCheckResult> checkForUpdate({
    required String currentVersion,
    required int currentBuild,
    required String platform,
    required String channel,
  }) async {
    checkCount += 1;
    return const AppUpdateCheckResult(
      updateAvailable: true,
      release: testRelease,
    );
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
  final List<String> downloadedVersions = [];
  final List<String> downloadedPlatforms = [];

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
    return const AppUpdateDownloadResult(
      filePath: '/tmp/FrameLean-v1.2.2-setup.exe',
    );
  }
}

class FakeAppUpdateInstallIdStore implements AppUpdateInstallIdStore {
  const FakeAppUpdateInstallIdStore();

  @override
  Future<String> loadOrCreateInstallId() async {
    return 'install-id-1';
  }
}

class FakeUpdaterHelperLauncher implements UpdaterHelperLauncher {
  final List<UpdaterHelperLaunchRequest> requests = [];

  @override
  Future<void> launch(UpdaterHelperLaunchRequest request) async {
    requests.add(request);
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
