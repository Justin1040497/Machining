import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/infrastructure/library.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('launches the app shell and navigates to settings', (
    tester,
  ) async {
    await pumpFrameLeanApp(tester);

    expect(find.textContaining('暂无任务'), findsOneWidget);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('返回工作台'), findsOneWidget);
    expect(find.text('应用设置'), findsWidgets);

    await tester.tap(find.text('返回工作台'));
    await tester.pumpAndSettle();
    expect(find.textContaining('暂无任务'), findsOneWidget);
  });

  testWidgets(
    'imports selected files and groups same-kind batch into a folder',
    (tester) async {
      final tempDir = await createTempDirectory();
      final first = await createFixtureFile(tempDir, 'podcast-a.mp3');
      final second = await createFixtureFile(tempDir, 'podcast-b.mp3');
      final selection = FakeFileSelectionService(
        importPaths: [first.path, second.path],
        defaultExportPath: tempDir.path,
      );

      await pumpFrameLeanApp(
        tester,
        overrides: [
          fileSelectionServiceProvider.overrideWithValue(selection),
          ffmpegRuntimeProvider.overrideWithBuild(
            (ref, notifier) => fakeFfmpegRuntime,
          ),
          mediaAnalyzerProvider.overrideWithValue(FakeMediaAnalyzer()),
        ],
      );

      await tester.tap(find.byTooltip('添加文件或文件夹'));
      await pumpUntilFound(tester, find.text('音频任务夹 1'));

      expect(find.text('音频任务夹 1'), findsOneWidget);
      expect(find.text('podcast-a.mp3'), findsNothing);
      expect(find.text('podcast-b.mp3'), findsNothing);

      await tester.tap(find.byTooltip('查看夹内任务'));
      await pumpUntilFound(tester, find.text('podcast-a.mp3'));

      expect(find.text('podcast-a.mp3'), findsOneWidget);
      expect(find.text('podcast-b.mp3'), findsOneWidget);
    },
  );

  testWidgets('opens persisted notifications and clears them from the center', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftAppNotificationRepository(database);
    await repository.saveNotification(
      AppNotificationEntry(
        id: 'integration-notification',
        level: AppNotificationLevel.success,
        title: '集成测试通知',
        message: '通知中心读取持久化消息',
        source: 'integration-test',
        createdAt: DateTime(2026, 6, 25, 12),
      ),
    );

    await pumpFrameLeanApp(tester, database: database);

    await tester.tap(find.byTooltip('通知中心'));
    await pumpUntilFound(tester, find.text('集成测试通知'));

    expect(find.text('通知中心'), findsOneWidget);
    expect(find.text('通知中心读取持久化消息'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-center-clear')));
    await pumpUntilFound(tester, find.text('暂无通知'));

    expect(find.text('集成测试通知'), findsNothing);
  });

  testWidgets('manual update check exposes the workbench update entry', (
    tester,
  ) async {
    final fixture = await pumpFrameLeanApp(
      tester,
      overrides: [
        appUpdateClientProvider.overrideWithValue(FakeAppUpdateClient()),
        appUpdateDownloaderProvider.overrideWithValue(
          const FakeAppUpdatePackageDownloader(),
        ),
        appUpdateDownloadStateStoreProvider.overrideWithValue(
          FakeAppUpdateDownloadStateStore(),
        ),
        appUpdateSnoozeStoreProvider.overrideWithValue(
          FakeAppUpdateSnoozeStore(),
        ),
        currentUpdatePlatformProvider.overrideWithValue('windows-installer'),
      ],
    );

    await fixture.container.read(appUpdateProvider.notifier).checkForUpdate();
    await pumpUntilFound(tester, find.text('新版本 v1.2.2'));

    expect(find.text('新版本 v1.2.2'), findsOneWidget);

    await tester.tap(find.text('新版本 v1.2.2'));
    await pumpUntilFound(tester, find.text('更新体验优化'));

    expect(find.text('下载更新'), findsOneWidget);
  });
}

const fakeFfmpegRuntime = ResolvedFfmpegRuntime(
  ffmpeg: null,
  ffprobe: ResolvedFfmpegTool(
    path: '/tmp/framelean-fake-ffprobe',
    source: FfmpegBinarySource.systemPath,
  ),
);

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

Future<AppIntegrationFixture> pumpFrameLeanApp(
  WidgetTester tester, {
  AppDatabase? database,
  List overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final appDatabase =
      database ?? AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(appDatabase.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(appDatabase),
        appRuntimeEffectsEnabledProvider.overrideWithValue(false),
        ...overrides,
      ],
      child: const FrameLeanApp(),
    ),
  );
  await tester.pumpAndSettle();

  final container = ProviderScope.containerOf(
    tester.element(find.byType(FrameLeanApp)),
  );
  return AppIntegrationFixture(database: appDatabase, container: container);
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (tester.any(finder)) {
      await tester.pumpAndSettle();
      return;
    }
  }
  expect(finder, findsOneWidget);
}

Future<Directory> createTempDirectory() async {
  final directory = await Directory.systemTemp.createTemp('framelean-it-');
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
  return directory;
}

Future<File> createFixtureFile(Directory directory, String name) async {
  final file = File(p.join(directory.path, name));
  await file.writeAsBytes([1, 2, 3, 4, 5, 6], flush: true);
  return file;
}

class AppIntegrationFixture {
  const AppIntegrationFixture({
    required this.database,
    required this.container,
  });

  final AppDatabase database;
  final ProviderContainer container;
}

class FakeFileSelectionService implements FileSelectionService {
  const FakeFileSelectionService({
    this.importPaths = const [],
    this.mediaFiles = const [],
    this.mediaDirectories = const [],
    this.mediaFile,
    this.mediaDirectory,
    this.outputDirectory,
    this.executablePath,
    required this.defaultExportPath,
  });

  final List<String> importPaths;
  final List<String> mediaFiles;
  final List<String> mediaDirectories;
  final String? mediaFile;
  final String? mediaDirectory;
  final String? outputDirectory;
  final String? executablePath;
  @override
  final String defaultExportPath;

  @override
  Future<List<String>> pickImportPaths() async => importPaths;

  @override
  Future<List<String>> pickMediaFiles() async => mediaFiles;

  @override
  Future<List<String>> pickMediaDirectories() async => mediaDirectories;

  @override
  Future<String?> pickMediaFile() async => mediaFile;

  @override
  Future<String?> pickMediaDirectory() async => mediaDirectory;

  @override
  Future<String?> pickOutputDirectory() async => outputDirectory;

  @override
  Future<String?> pickExecutablePath() async => executablePath;
}

class FakeMediaAnalyzer implements MediaAnalyzer {
  @override
  Future<MediaAnalysisResult> analyze({
    required String ffprobePath,
    required String inputPath,
  }) async {
    final extension = p.extension(inputPath).toLowerCase();
    if (extension == '.mp3') {
      return MediaAnalysisResult(
        durationMs: 120000,
        audioCodec: 'mp3',
        audioBitrate: 128000,
        audioChannels: 2,
        audioSampleRate: 44100,
        containerFormat: 'mp3',
      );
    }
    return MediaAnalysisResult(
      durationMs: 60000,
      videoWidth: 1920,
      videoHeight: 1080,
      videoCodec: 'h264',
      audioCodec: 'aac',
      containerFormat: 'mp4',
    );
  }
}

class FakeAppUpdateClient implements AppUpdateClient {
  @override
  Future<AppUpdateCheckResult> checkForUpdate({
    required String currentVersion,
    required int currentBuild,
    required String platform,
    required String channel,
  }) async {
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
    return AppUpdateDownloadTicket(
      downloadUrl: Uri.parse('https://framelean.example/download'),
      expiresAt: DateTime(2026, 6, 25, 12),
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

class FakeAppUpdatePackageDownloader implements AppUpdatePackageDownloader {
  const FakeAppUpdatePackageDownloader();

  @override
  Future<AppUpdateDownloadResult> download({
    required AppUpdateDownloadTicket ticket,
    required String version,
    required String platform,
    required AppUpdateDownloadCancellationToken cancellationToken,
    required AppUpdateDownloadProgressCallback onProgress,
  }) async {
    onProgress(ticket.package.sizeBytes, ticket.package.sizeBytes);
    return const AppUpdateDownloadResult(filePath: '/tmp/framelean-update.exe');
  }

  @override
  Future<String?> findExistingValidPackage({
    required AppUpdatePackageInfo package,
    required String version,
    required String platform,
  }) async {
    return null;
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

class FakeAppUpdateSnoozeStore implements AppUpdateSnoozeStore {
  String? _version;

  @override
  Future<String?> loadSnoozedVersion() async => _version;

  @override
  Future<void> saveSnoozedVersion(String version) async {
    _version = version;
  }

  @override
  Future<void> clearSnoozedVersion() async {
    _version = null;
  }
}
