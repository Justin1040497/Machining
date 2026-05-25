import 'package:flutter_test/flutter_test.dart';
import 'package:machining/application/services/execution/preview_frame_generator.dart';
import 'package:machining/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:machining/application/services/input_runtime/ffmpeg_runtime.dart';
import 'package:machining/application/use_cases/media_tasks/generate_preview_frames_use_case.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/encoder_backend.dart';
import 'package:machining/domain/enums/media_kind.dart';
import 'package:machining/domain/enums/task_purpose.dart';
import 'package:machining/domain/enums/task_status.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';
import 'package:machining/domain/value_objects/video_task_config.dart';

void main() {
  group('GeneratePreviewFramesUseCase', () {
    test('builds a preview request from the resolved FFmpeg runtime', () async {
      final generator = FakePreviewFrameGenerator();
      final capabilities = FfmpegEncoderCapabilities(
        encoderNames: const {'libx264', 'h264_videotoolbox'},
        autoBackendPriority: const [EncoderBackend.videotoolbox],
      );
      final runtime = ResolvedFfmpegRuntime(
        ffmpeg: const ResolvedFfmpegTool(
          path: '/usr/local/bin/ffmpeg',
          source: FfmpegBinarySource.systemPath,
        ),
        ffprobe: null,
        encoderCapabilities: capabilities,
      );

      final result = await GeneratePreviewFramesUseCase(
        readRuntime: () async => runtime,
        previewFrameGenerator: generator,
      ).call(task: testTask(), allowExtremeCompression: true);

      expect(result, same(generator.result));
      expect(generator.lastRequest?.ffmpegPath, '/usr/local/bin/ffmpeg');
      expect(generator.lastRequest?.task.id, 'task-1');
      expect(generator.lastRequest?.allowExtremeCompression, true);
      expect(generator.lastRequest?.encoderCapabilities, capabilities);
    });

    test('requires media analysis before generating preview frames', () async {
      final generator = FakePreviewFrameGenerator();
      final useCase = GeneratePreviewFramesUseCase(
        readRuntime: () async => resolvedRuntime,
        previewFrameGenerator: generator,
      );

      await expectLater(
        useCase.call(
          task: testTask(analysisResult: MediaAnalysisResult()),
          allowExtremeCompression: false,
        ),
        throwsA(
          isA<GeneratePreviewFramesException>().having(
            (error) => error.message,
            'message',
            '媒体分析完成后才能生成预览',
          ),
        ),
      );
      expect(generator.generateCallCount, 0);
    });

    test('requires FFmpeg before generating preview frames', () async {
      final generator = FakePreviewFrameGenerator();
      final useCase = GeneratePreviewFramesUseCase(
        readRuntime: () async {
          return const ResolvedFfmpegRuntime(ffmpeg: null, ffprobe: null);
        },
        previewFrameGenerator: generator,
      );

      await expectLater(
        useCase.call(task: testTask(), allowExtremeCompression: false),
        throwsA(
          isA<GeneratePreviewFramesException>().having(
            (error) => error.message,
            'message',
            'FFmpeg 不可用，无法生成预览',
          ),
        ),
      );
      expect(generator.generateCallCount, 0);
    });
  });
}

const resolvedRuntime = ResolvedFfmpegRuntime(
  ffmpeg: ResolvedFfmpegTool(
    path: '/usr/bin/ffmpeg',
    source: FfmpegBinarySource.systemPath,
  ),
  ffprobe: null,
);

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
    return result;
  }
}
