import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/app/constants.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/infrastructure/library.dart';
import 'package:framelean/app/providers/app_notification_provider.dart';
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

/// FFmpeg 任务队列执行器。Provider 会在容器生命周期内维持同一个执行器实例。
final ffmpegTaskQueueRunnerProvider = Provider<FfmpegTaskQueueRunner>((ref) {
  return DefaultFfmpegTaskQueueRunner(
    repository: ref.read(mediaTaskRepositoryProvider),
    taskFolderRepository: ref.read(taskFolderRepositoryProvider),
    sourceFileChecker: ref.read(sourceFileCheckerProvider),
    readSettings: () => ref.read(appSettingsRepositoryProvider).loadSettings(),
    readRuntime: () => ref.read(ffmpegRuntimeProvider.future),
    commandBuilder: ref.read(ffmpegCommandBuilderProvider),
    resourceGuard: ref.read(executionResourceGuardProvider),
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
});

Directory ffmpegExecutionLogsDirectory() {
  return Directory(
    path.join(Directory.systemTemp.path, ffmpegLogsSubDir),
  );
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
