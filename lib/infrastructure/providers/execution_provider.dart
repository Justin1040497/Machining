import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_controller.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_observer.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_starter.dart';
import 'package:framelean/application/services/execution/ffmpeg_task_queue_runner.dart';
import 'package:framelean/application/services/execution/preview_frame_generator.dart';
import 'package:framelean/application/services/execution/video_thumbnail_generator.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/infrastructure/providers/ffmpeg_planning_provider.dart';
import 'package:framelean/infrastructure/providers/input_runtime_provider.dart';
import 'package:framelean/infrastructure/providers/repository_provider.dart';
import 'package:framelean/infrastructure/services/execution/local_ffmpeg_process_observer.dart';
import 'package:framelean/infrastructure/services/execution/local_ffmpeg_process_starter.dart';
import 'package:framelean/infrastructure/services/execution/local_preview_frame_generator.dart';
import 'package:framelean/infrastructure/services/execution/local_video_thumbnail_generator.dart';
import 'package:framelean/infrastructure/services/execution/signal_ffmpeg_process_controller.dart';
import 'package:framelean/infrastructure/services/execution/windows_ffmpeg_process_controller.dart';
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

/// FFmpeg 任务队列执行器。Provider 会在容器生命周期内维持同一个执行器实例。
final ffmpegTaskQueueRunnerProvider = Provider<FfmpegTaskQueueRunner>((ref) {
  return DefaultFfmpegTaskQueueRunner(
    repository: ref.read(mediaTaskRepositoryProvider),
    sourceFileChecker: ref.read(sourceFileCheckerProvider),
    readRuntime: () => ref.read(ffmpegRuntimeProvider.future),
    commandBuilder: ref.read(ffmpegCommandBuilderProvider),
    processStarter: ref.read(ffmpegProcessStarterProvider),
    processController: ref.read(ffmpegProcessControllerProvider),
    processObserver: ref.read(ffmpegProcessObserverProvider),
    createLogFilePath: createFfmpegExecutionLogFilePath,
  );
});

Future<String> createFfmpegExecutionLogFilePath(
  MediaTask task,
  FfmpegCommandPlan _,
) async {
  final logsDirectory = Directory(
    path.join(Directory.systemTemp.path, 'framelean', 'ffmpeg-logs'),
  );
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
