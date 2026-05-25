import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machining/application/services/execution/preview_frame_generator.dart';
import 'package:machining/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:machining/application/services/input_runtime/ffmpeg_runtime.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/media_kind.dart';
import 'package:machining/domain/enums/task_purpose.dart';
import 'package:machining/domain/enums/task_status.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';
import 'package:machining/domain/value_objects/video_task_config.dart';
import 'package:machining/features/workbench/providers/workbench_preview_notifier.dart';
import 'package:machining/infrastructure/providers/ffmpeg_provider.dart';

void main() {
  group('WorkbenchPreviewNotifier', () {
    test('generates preview frames through the preview entry point', () async {
      final generator = FakePreviewFrameGenerator();
      final container = previewContainer(generator: generator);

      await container
          .read(workbenchPreviewProvider.notifier)
          .generate(task: testTask(), allowExtremeCompression: true);

      final state = container.read(workbenchPreviewProvider);
      expect(state.generating, false);
      expect(state.result, same(generator.result));
      expect(state.selectedFrameIndex, 0);
      expect(state.compareRatio, 0.5);
      expect(state.errorMessage, isNull);
      expect(generator.lastRequest?.ffmpegPath, '/usr/bin/ffmpeg');
      expect(generator.lastRequest?.allowExtremeCompression, true);
      expect(
        generator.lastRequest?.encoderCapabilities,
        FfmpegEncoderCapabilities.softwareOnly,
      );
    });

    test('keeps validation errors in preview state', () async {
      final generator = FakePreviewFrameGenerator();
      final container = previewContainer(generator: generator);

      await container
          .read(workbenchPreviewProvider.notifier)
          .generate(
            task: testTask(analysisResult: MediaAnalysisResult()),
            allowExtremeCompression: false,
          );

      final state = container.read(workbenchPreviewProvider);
      expect(state.generating, false);
      expect(state.result, isNull);
      expect(state.errorMessage, '媒体分析完成后才能生成预览');
      expect(generator.generateCallCount, 0);
    });

    test('reports unavailable FFmpeg without calling the generator', () async {
      final generator = FakePreviewFrameGenerator();
      final container = previewContainer(
        generator: generator,
        runtime: const ResolvedFfmpegRuntime(ffmpeg: null, ffprobe: null),
      );

      await container
          .read(workbenchPreviewProvider.notifier)
          .generate(task: testTask(), allowExtremeCompression: false);

      final state = container.read(workbenchPreviewProvider);
      expect(state.generating, false);
      expect(state.result, isNull);
      expect(state.errorMessage, 'FFmpeg 不可用，无法生成预览');
      expect(generator.generateCallCount, 0);
    });

    test('reset ignores a stale preview generation result', () async {
      final completer = Completer<PreviewFrameResult>();
      final generator = FakePreviewFrameGenerator(completer: completer);
      final container = previewContainer(generator: generator);

      final generation = container
          .read(workbenchPreviewProvider.notifier)
          .generate(task: testTask(), allowExtremeCompression: false);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(workbenchPreviewProvider).generating, true);

      container.read(workbenchPreviewProvider.notifier).reset();
      completer.complete(generator.result);
      await generation;

      final state = container.read(workbenchPreviewProvider);
      expect(state.generating, false);
      expect(state.result, isNull);
      expect(state.errorMessage, isNull);
    });

    test('updates preview-only view state', () {
      final container = previewContainer();
      final notifier = container.read(workbenchPreviewProvider.notifier);

      notifier.setCompareRatio(1);
      notifier.selectFrame(-1);

      var state = container.read(workbenchPreviewProvider);
      expect(state.compareRatio, 0.98);
      expect(state.selectedFrameIndex, 0);

      notifier.setCompareRatio(0);
      notifier.selectFrame(3);

      state = container.read(workbenchPreviewProvider);
      expect(state.compareRatio, 0.02);
      expect(state.selectedFrameIndex, 3);
    });
  });
}

ProviderContainer previewContainer({
  FakePreviewFrameGenerator? generator,
  ResolvedFfmpegRuntime runtime = const ResolvedFfmpegRuntime(
    ffmpeg: ResolvedFfmpegTool(
      path: '/usr/bin/ffmpeg',
      source: FfmpegBinarySource.systemPath,
    ),
    ffprobe: null,
  ),
}) {
  return ProviderContainer.test(
    overrides: [
      ffmpegRuntimeProvider.overrideWithBuild((ref, notifier) => runtime),
      previewFrameGeneratorProvider.overrideWithValue(
        generator ?? FakePreviewFrameGenerator(),
      ),
    ],
  );
}

MediaTask testTask({MediaAnalysisResult? analysisResult}) {
  return MediaTask(
    id: 'task-1',
    inputPath: '/videos/source.mp4',
    fileName: 'source.mp4',
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: TaskStatus.pending,
    config: VideoTaskConfig.initial(),
    progress: 0,
    sortOrder: 0,
    createdAt: 1,
    analysisResult:
        analysisResult ??
        MediaAnalysisResult(
          durationMs: 60000,
          videoWidth: 1920,
          videoHeight: 1080,
          videoCodec: 'h264',
          videoBitrate: 4000000,
          audioBitrate: 128000,
        ),
  );
}

class FakePreviewFrameGenerator implements PreviewFrameGenerator {
  FakePreviewFrameGenerator({this.completer});

  final Completer<PreviewFrameResult>? completer;
  final result = const PreviewFrameResult(
    taskId: 'task-1',
    directoryPath: '/tmp/previews/task-1',
    fingerprint: PreviewFrameFingerprint('fingerprint'),
    frames: [
      PreviewFramePair(
        index: 0,
        ratio: 0.5,
        timestampSeconds: 30,
        originalFramePath: '/tmp/previews/task-1/original.jpg',
        previewFramePath: '/tmp/previews/task-1/preview.jpg',
      ),
    ],
  );

  int generateCallCount = 0;
  PreviewFrameRequest? lastRequest;

  @override
  PreviewFrameFingerprint buildFingerprint(
    MediaTask task, {
    bool allowExtremeCompression = false,
    FfmpegEncoderCapabilities encoderCapabilities =
        FfmpegEncoderCapabilities.softwareOnly,
  }) {
    return const PreviewFrameFingerprint('fingerprint');
  }

  @override
  Future<PreviewFrameResult> generate(PreviewFrameRequest request) async {
    generateCallCount += 1;
    lastRequest = request;
    return completer?.future ?? result;
  }
}
