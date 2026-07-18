import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/app/providers/ffmpeg_planning_provider.dart';
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
    await pumpUntilFound(tester, find.text('返回工作台'));

    expect(find.text('返回工作台'), findsOneWidget);
    expect(find.text('应用设置'), findsWidgets);

    await tester.tap(find.text('返回工作台'));
    await pumpUntilFound(tester, find.textContaining('暂无任务'));
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

  testWidgets('imports analyzes exports and reveals a video result', (
    tester,
  ) async {
    final tempDir = await createTempDirectory();
    final source = await createFixtureFile(tempDir, '稳定链路 source.mp4');
    final selection = FakeFileSelectionService(
      importPaths: [source.path],
      defaultExportPath: tempDir.path,
    );
    final revealer = FakeFileRevealer();

    final fixture = await pumpFrameLeanApp(
      tester,
      overrides: [
        fileSelectionServiceProvider.overrideWithValue(selection),
        fileRevealerProvider.overrideWithValue(revealer),
        ffmpegRuntimeProvider.overrideWithBuild(
          (ref, notifier) => fakeExecutableFfmpegRuntime,
        ),
        mediaAnalyzerProvider.overrideWithValue(FakeMediaAnalyzer()),
        ffmpegCommandBuilderProvider.overrideWithValue(
          const FakeIntegrationCommandBuilder(),
        ),
        ffmpegProcessStarterProvider.overrideWithValue(
          const FakeIntegrationProcessStarter(),
        ),
        ffmpegProcessControllerProvider.overrideWithValue(
          const FakeIntegrationProcessController(),
        ),
        ffmpegProcessObserverProvider.overrideWithValue(
          const FakeIntegrationProcessObserver(),
        ),
      ],
    );

    await tester.tap(find.byTooltip('添加文件或文件夹'));
    await pumpUntilFound(tester, find.text('稳定链路 source.mp4'));
    final analyzedTask = await pumpUntilAnalyzedTask(tester, fixture);
    expect(analyzedTask.status, TaskStatus.pending);
    expect(analyzedTask.analysisResult, isNotNull);
    final startAction = find.byIcon(Icons.play_circle_fill_rounded);
    await pumpUntilFound(tester, startAction);

    await pressIconAction(tester, startAction);
    final revealAction = find.byIcon(Icons.file_open_outlined);
    await pumpUntilFound(tester, revealAction);

    await pressIconAction(tester, revealAction);
    await tester.pump();

    expect(revealer.paths, hasLength(1));
    expect(await File(revealer.paths.single).exists(), isTrue);
    expect(await File(revealer.paths.single).length(), greaterThan(0));
  });

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

const fakeExecutableFfmpegRuntime = ResolvedFfmpegRuntime(
  ffmpeg: ResolvedFfmpegTool(
    path: '/framelean-test/ffmpeg',
    source: FfmpegBinarySource.systemPath,
  ),
  ffprobe: ResolvedFfmpegTool(
    path: '/framelean-test/ffprobe',
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
        taskCompletionSoundPlayerProvider.overrideWithValue(
          const FakeTaskCompletionSoundPlayer(),
        ),
        ...overrides,
      ],
      child: const FrameLeanApp(),
    ),
  );
  await tester.pumpAndSettle();

  final container = ProviderScope.containerOf(
    tester.element(find.byType(FrameLeanApp)),
  );
  final analysisQueue = container.read(mediaAnalysisQueueProvider);
  final taskQueueRunner = container.read(ffmpegTaskQueueRunnerProvider);
  final workScheduler = container.read(mediaWorkSchedulerProvider);
  addTearDown(() async {
    await analysisQueue.stop();
    await taskQueueRunner.dispose();
    await workScheduler.stop();
  });
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
      // The real app owns periodic resource-monitor timers after media work is
      // initialized, so pumpAndSettle would wait forever even though the UI
      // condition is already satisfied.
      await tester.pump(const Duration(milliseconds: 500));
      return;
    }
  }
  expect(finder, findsOneWidget);
}

Future<void> pressIconAction(WidgetTester tester, Finder iconFinder) async {
  final buttonFinder = find.ancestor(
    of: iconFinder,
    matching: find.byType(IconButton),
  );
  expect(buttonFinder, findsOneWidget);
  final onPressed = tester.widget<IconButton>(buttonFinder).onPressed;
  expect(onPressed, isNotNull);
  onPressed!();
  await tester.pump();
}

Future<MediaTask> pumpUntilAnalyzedTask(
  WidgetTester tester,
  AppIntegrationFixture fixture, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(timeout);
  MediaTask? latest;
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    final tasks = await fixture.container
        .read(mediaTaskRepositoryProvider)
        .loadAllTasks();
    if (tasks.isNotEmpty) {
      latest = tasks.single;
      if (latest.analysisResult != null) {
        return latest;
      }
    }
  }
  fail(
    '等待媒体分析超时，最后状态: '
    '${latest?.status}, 错误: ${latest?.errorMessage ?? latest?.analysisErrorMessage}',
  );
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

class FakeTaskCompletionSoundPlayer implements TaskCompletionSoundPlayer {
  const FakeTaskCompletionSoundPlayer();

  @override
  Future<void> play(TaskCompletionSound sound) async {}
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

class FakeIntegrationCommandBuilder implements FfmpegCommandBuilder {
  const FakeIntegrationCommandBuilder();

  @override
  FfmpegCommandPlan build(
    MediaTask task, {
    bool allowExtremeCompression = false,
    FfmpegEncoderCapabilities encoderCapabilities =
        FfmpegEncoderCapabilities.softwareOnly,
  }) {
    final outputPath = p.join(
      p.dirname(task.inputPath),
      '${p.basenameWithoutExtension(task.inputPath)}-压缩.mp4',
    );
    return FfmpegCommandPlan(
      args: ['-i', task.inputPath, outputPath],
      outputPath: outputPath,
      logHint: '集成烟测模拟输出',
    );
  }
}

class FakeIntegrationProcessStarter implements FfmpegProcessStarter {
  const FakeIntegrationProcessStarter();

  @override
  Future<StartedFfmpegProcess> start({
    required String ffmpegPath,
    required List<String> args,
    required File logFile,
  }) async {
    await File(args.last).writeAsBytes([1, 2, 3, 4], flush: true);
    final process = Platform.isWindows
        ? await Process.start('cmd.exe', ['/c', 'exit', '0'])
        : await Process.start('/usr/bin/true', const []);
    return StartedFfmpegProcess(process: process, logFile: logFile);
  }
}

class FakeIntegrationProcessController implements FfmpegProcessController {
  const FakeIntegrationProcessController();

  @override
  Future<void> pause(StartedFfmpegProcess startedProcess) async {}

  @override
  Future<void> resume(StartedFfmpegProcess startedProcess) async {}

  @override
  Future<void> terminate(StartedFfmpegProcess startedProcess) async {
    startedProcess.process.kill();
  }
}

class FakeIntegrationProcessObserver implements FfmpegProcessObserver {
  const FakeIntegrationProcessObserver();

  @override
  Future<FfmpegProcessObservation> observe({
    required StartedFfmpegProcess startedProcess,
    required MediaTask task,
    required String? outputPath,
    ProgressMode progressMode = ProgressMode.timed,
    required Future<void> Function(double progress) onProgress,
  }) async {
    await onProgress(1);
    await startedProcess.process.exitCode;
    return const FfmpegProcessObservation.completed();
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
