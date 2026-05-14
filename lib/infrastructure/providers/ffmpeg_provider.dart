import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:machining/application/services/compression_advisor.dart';
import 'package:machining/application/services/ffmpeg_command_builder.dart';
import 'package:machining/application/services/ffmpeg_locator.dart';
import 'package:machining/application/services/ffmpeg_process_observer.dart';
import 'package:machining/application/services/ffmpeg_process_starter.dart';
import 'package:machining/application/services/ffmpeg_task_queue_runner.dart';
import 'package:machining/application/services/media_analyzer.dart';
import 'package:machining/application/services/preview_frame_generator.dart';
import 'package:machining/application/services/video_thumbnail_generator.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/infrastructure/providers/drift_provider.dart';
import 'package:machining/infrastructure/services/default_compression_advisor.dart';
import 'package:machining/infrastructure/services/default_ffmpeg_command_builder.dart';
import 'package:machining/infrastructure/services/ffprobe_media_analyzer.dart';
import 'package:machining/infrastructure/services/local_ffmpeg_locator.dart';
import 'package:machining/infrastructure/services/local_ffmpeg_process_observer.dart';
import 'package:machining/infrastructure/services/local_ffmpeg_process_starter.dart';
import 'package:machining/infrastructure/services/local_preview_frame_generator.dart';
import 'package:machining/infrastructure/services/local_video_thumbnail_generator.dart';
import 'package:path/path.dart' as path;

/// FFmpeg / FFprobe 路径解析服务
final ffmpegLocatorProvider = Provider<FfmpegLocator>((ref) {
  return LocalFfmpegLocator();
});

/// FFprobe 媒体分析服务
final mediaAnalyzerProvider = Provider<MediaAnalyzer>((ref) {
  return FfprobeMediaAnalyzer();
});

/// FFmpeg 命令构造服务，只生成参数计划，不启动进程
final compressionAdvisorProvider = Provider<CompressionAdvisor>((ref) {
  return DefaultCompressionAdvisor();
});

/// FFmpeg 命令构造服务，只生成参数计划，不启动进程
final defaultFfmpegCommandBuilderProvider =
    Provider<DefaultFfmpegCommandBuilder>((ref) {
      return DefaultFfmpegCommandBuilder(
        compressionAdvisor: ref.watch(compressionAdvisorProvider),
      );
    });

/// FFmpeg 命令构造服务，只生成参数计划，不启动进程
final ffmpegCommandBuilderProvider = Provider<FfmpegCommandBuilder>((ref) {
  return ref.watch(defaultFfmpegCommandBuilderProvider);
});

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
    processObserver: ref.read(ffmpegProcessObserverProvider),
    createLogFilePath: createFfmpegExecutionLogFilePath,
  );
});

/// 当前 FFmpeg / FFprobe 运行时状态
final ffmpegRuntimeProvider =
    AsyncNotifierProvider<FfmpegRuntimeNotifier, ResolvedFfmpegRuntime>(
      FfmpegRuntimeNotifier.new,
    );

class FfmpegRuntimeNotifier extends AsyncNotifier<ResolvedFfmpegRuntime> {
  @override
  Future<ResolvedFfmpegRuntime> build() async {
    final settingsRepository = ref.watch(appSettingsRepositoryProvider);
    final locator = ref.watch(ffmpegLocatorProvider);
    final settings = await settingsRepository.loadSettings();

    return locator.resolve(
      customFfmpegPath: settings.customFfmpegPath,
      customFfprobePath: settings.customFfprobePath,
    );
  }

  Future<void> updateCustomFfmpegPath(String inputPath) async {
    final locator = ref.read(ffmpegLocatorProvider);
    final settingsRepository = ref.read(appSettingsRepositoryProvider);

    await locator.validateCustomFfmpegPath(inputPath);

    final settings = await settingsRepository.loadSettings();
    final updatedSettings = settings.withCustomFfmpegPath(inputPath);
    await settingsRepository.saveSettings(updatedSettings);
    final runtime = await locator.resolve(
      customFfmpegPath: updatedSettings.customFfmpegPath,
      customFfprobePath: updatedSettings.customFfprobePath,
    );

    state = AsyncData(runtime);
  }

  Future<void> updateCustomFfprobePath(String inputPath) async {
    final locator = ref.read(ffmpegLocatorProvider);
    final settingsRepository = ref.read(appSettingsRepositoryProvider);

    await locator.validateCustomFfprobePath(inputPath);

    final settings = await settingsRepository.loadSettings();
    final updatedSettings = settings.withCustomFfprobePath(inputPath);
    await settingsRepository.saveSettings(updatedSettings);
    final runtime = await locator.resolve(
      customFfmpegPath: updatedSettings.customFfmpegPath,
      customFfprobePath: updatedSettings.customFfprobePath,
    );

    state = AsyncData(runtime);
  }
}

Future<String> createFfmpegExecutionLogFilePath(
  MediaTask task,
  FfmpegCommandPlan _,
) async {
  final logsDirectory = Directory(
    path.join(Directory.systemTemp.path, 'machining', 'ffmpeg-logs'),
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
