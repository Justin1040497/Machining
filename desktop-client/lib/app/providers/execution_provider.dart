import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/infrastructure/library.dart';
import 'package:framelean/app/providers/app_notification_provider.dart';
import 'package:framelean/app/providers/engine_provider.dart';
import 'package:framelean/app/providers/ffmpeg_planning_provider.dart';
import 'package:framelean/app/providers/input_runtime_provider.dart';
import 'package:framelean/app/providers/repository_provider.dart';
import 'package:path/path.dart' as path;

/// FFmpeg 预览帧生成服务，按当前压缩参数生成 5 组原始/压缩对比帧
final previewFrameGeneratorProvider = Provider<PreviewFrameGenerator>((ref) {
  return LocalPreviewFrameGenerator(
    commandBuilder: ref.watch(defaultFfmpegCommandBuilderProvider),
    compressionAdvisor: ref.watch(compressionAdvisorProvider),
  );
});

/// FFmpeg 视频缩略图生成服务，自动跳过黑屏帧。
final videoThumbnailGeneratorProvider = Provider<VideoThumbnailGenerator>((
  ref,
) {
  return const LocalVideoThumbnailGenerator();
});

/// FFmpeg 进程启动服务，只负责把命令计划启动成系统进程
final ffmpegProcessStarterProvider = Provider<FfmpegProcessStarter>((ref) {
  return LocalFfmpegProcessStarter();
});

/// FFmpeg 进程控制服务，封装暂停、继续和终止的跨平台差异。
final ffmpegProcessControllerProvider = Provider<FfmpegProcessController>((
  ref,
) {
  if (Platform.isWindows) {
    return const WindowsFfmpegProcessController();
  }

  return const SignalFfmpegProcessController();
});

/// FFmpeg 进程观测服务，负责进度、日志和退出结果判断
final ffmpegProcessObserverProvider = Provider<FfmpegProcessObserver>((ref) {
  return LocalFfmpegProcessObserver();
});

/// 执行日志读取服务。FFmpeg stderr 日志保存在临时目录，不写入 SQLite。
final executionLogStoreProvider = Provider<ExecutionLogStore>((ref) {
  return ExecutionLogStore(logsDirectory: ffmpegExecutionLogsDirectory());
});

final outputPreflightServiceProvider = Provider<LocalOutputPreflightService>((
  ref,
) {
  return LocalOutputPreflightService();
});

final executionResourceGuardProvider = Provider<ExecutionResourceGuard>((ref) {
  return const LocalExecutionResourceGuard();
});

/// 全局媒体工作资源调度器，管理所有媒体工作的资源分配。
final mediaWorkSchedulerProvider = Provider<MediaWorkScheduler>((ref) {
  final monitor = ref.read(mediaResourceMonitorProvider);
  monitor.start();

  final scheduler = MediaWorkScheduler(resourceMonitor: monitor);
  ref.onDispose(() {
    unawaited(scheduler.stop());
    unawaited(monitor.stop());
  });
  return scheduler;
});

/// 全局系统资源监控器，每 1 秒采样内存，计算压力级别。
final mediaResourceMonitorProvider = Provider<MediaResourceMonitor>((ref) {
  return MediaResourceMonitor();
});

/// Client-side analysis submission coordinator. FEngine owns the external
/// work queue and FLL owns the actual analysis.
final mediaAnalysisQueueProvider = Provider<MediaAnalysisQueue>((ref) {
  final queue = MediaAnalysisQueue(
    analyzeTask: (taskId) async {
      final repository = ref.read(mediaTaskRepositoryProvider);
      final projectionRepository = ref.read(
        engineAnalysisProjectionRepositoryProvider,
      );

      final useCase = AnalyzeMediaTaskUseCase(
        repository: repository,
        analysisProjectionRepository: projectionRepository,
        readEngineGateway: () => ref.read(engineGatewayProvider.future),
      );

      return useCase.call(taskId);
    },
  );

  ref.onDispose(() {
    // 容器销毁时停止队列，防止子进程泄漏
    unawaited(queue.stop());
  });

  return queue;
});

/// FFmpeg 任务队列执行器。Provider 会在容器生命周期内维持同一个执行器实例。
final ffmpegTaskQueueRunnerProvider = Provider<FfmpegTaskQueueRunner>((ref) {
  final runner = DefaultFfmpegTaskQueueRunner(
    repository: ref.read(mediaTaskRepositoryProvider),
    taskFolderRepository: ref.read(taskFolderRepositoryProvider),
    sourceFileChecker: ref.read(sourceFileCheckerProvider),
    readSettings: () => ref.read(appSettingsRepositoryProvider).loadSettings(),
    readRuntime: () => ref.read(ffmpegRuntimeProvider.future),
    commandBuilder: ref.read(ffmpegCommandBuilderProvider),
    resourceGuard: ref.read(executionResourceGuardProvider),
    workScheduler: ref.read(mediaWorkSchedulerProvider),
    mediaInputPreparer: ref.read(mediaInputPreparerProvider),
    outputPreflightService: ref.read(outputPreflightServiceProvider),
    processStarter: ref.read(ffmpegProcessStarterProvider),
    processController: ref.read(ffmpegProcessControllerProvider),
    processObserver: ref.read(ffmpegProcessObserverProvider),
    createLogFilePath: createFfmpegExecutionLogFilePath,
    onTaskCompleted: ref
        .read(appNotificationManagerProvider)
        .notifyTaskCompleted,
    onTaskFailed: ref.read(appNotificationManagerProvider).notifyTaskFailed,
  );
  ref.onDispose(() {
    unawaited(runner.dispose());
  });
  return runner;
});

/// Engine execution submission is a process-boundary operation. The provider
/// keeps one use-case instance so duplicate submissions for the same task can
/// be rejected while a request is in flight.
final submitEngineExecutionUseCaseProvider =
    Provider<SubmitEngineExecutionUseCase>((ref) {
      return SubmitEngineExecutionUseCase(
        repository: ref.read(mediaTaskRepositoryProvider),
        analysisProjectionRepository: ref.read(
          engineAnalysisProjectionRepositoryProvider,
        ),
        settingsRepository: ref.read(appSettingsRepositoryProvider),
        readEngineGateway: () => ref.read(engineGatewayProvider.future),
        onTaskFailed: (task) async {
          await ref.read(appNotificationManagerProvider).notifyTaskFailed(task);
        },
      );
    });

/// Routes all Client execution requests to the FEngine process boundary.
///
/// The legacy runner provider remains available to migration-only controls
/// (pause, cancellation and cleanup) until those surfaces move to Engine APIs.
/// It is intentionally not injected into the execution coordinator.
final mediaTaskExecutionCoordinatorProvider =
    Provider<MediaTaskExecutionCoordinator>((ref) {
      return MediaTaskExecutionCoordinator(
        repository: ref.read(mediaTaskRepositoryProvider),
        analysisProjectionRepository: ref.read(
          engineAnalysisProjectionRepositoryProvider,
        ),
        taskFolderRepository: ref.read(taskFolderRepositoryProvider),
        submitEngineExecution: ref.read(submitEngineExecutionUseCaseProvider),
        readEngineGateway: () => ref.read(engineGatewayProvider.future),
      );
    });

Directory ffmpegExecutionLogsDirectory() {
  return Directory(path.join(Directory.systemTemp.path, ffmpegLogsSubDir));
}

Future<String> createFfmpegExecutionLogFilePath(
  MediaTask task,
  FfmpegCommandPlan _,
) async {
  final logsDirectory = ffmpegExecutionLogsDirectory();
  final safeFileName = task.fileName.replaceAll(
    RegExp(r'[^A-Za-z0-9._-]'),
    '_',
  );
  final timestamp = DateTime.now().millisecondsSinceEpoch;

  return path.join(
    logsDirectory.path,
    '${timestamp}_${task.id}_$safeFileName.log',
  );
}
