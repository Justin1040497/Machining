import 'package:flutter_test/flutter_test.dart';
import 'package:machining/application/services/ffmpeg_command_builder.dart';
import 'package:machining/application/services/ffmpeg_encoder_capabilities.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/compression_mode.dart';
import 'package:machining/domain/enums/encoder_backend.dart';
import 'package:machining/domain/enums/media_kind.dart';
import 'package:machining/domain/enums/output_format.dart';
import 'package:machining/domain/enums/resolution_preset.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/task_purpose.dart';
import 'package:machining/domain/enums/task_status.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';
import 'package:machining/domain/value_objects/source_file_fingerprint.dart';
import 'package:machining/domain/value_objects/video_task_config.dart';
import 'package:machining/infrastructure/services/default_ffmpeg_command_builder.dart';

void main() {
  group('DefaultFfmpegCommandBuilder', () {
    test('builds compression command with normal recommendation', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        inputPath: '/videos/source.mov',
        fileName: 'source.mov',
        purpose: TaskPurpose.compression,
        analysisResult: MediaAnalysisResult(
          videoHeight: 1080,
          videoBitrate: 3000000,
        ),
      );

      final plan = builder.build(task);

      expect(plan.outputPath, '/videos/source_compressed.mp4');
      expect(plan.args, [
        '-hide_banner',
        '-i',
        '/videos/source.mov',
        '-c:v',
        'libx264',
        '-preset',
        'slow',
        '-crf',
        '28',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-b:a',
        '96k',
        '-movflags',
        '+faststart',
        '-progress',
        'pipe:1',
        '/videos/source_compressed.mp4',
      ]);
    });

    test('uses target bitrate after low bitrate video is confirmed', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        inputPath: '/videos/source.mp4',
        fileName: 'source.mp4',
        analysisResult: MediaAnalysisResult(
          videoHeight: 1080,
          videoBitrate: 550000,
          audioBitrate: 128000,
        ),
      );

      final plan = builder.build(task, allowExtremeCompression: true);

      expect(plan.args, isNot(contains('-crf')));
      expect(plan.args, containsAllInOrder(['-b:v', '404k']));
      expect(plan.args, containsAllInOrder(['-maxrate', '404k']));
      expect(plan.args, containsAllInOrder(['-bufsize', '807k']));
      expect(plan.args, containsAllInOrder(['-b:a', '64k']));
      expect(plan.args, isNot(contains('-vf')));
      expect(plan.logHint, contains('目标分辨率 保持原始'));
    });

    test('uses configured normal compression crf', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        config: VideoTaskConfig.initial().copyWith(
          videoCodec: VideoCodec.h264,
          compressionCrf: 24,
        ),
        analysisResult: MediaAnalysisResult(
          videoHeight: 1080,
          videoBitrate: 3000000,
        ),
      );

      final plan = builder.build(task);

      expect(plan.args, containsAllInOrder(['-crf', '24']));
      expect(plan.logHint, contains('CRF 24'));
    });

    test('uses target bitrate for target size compression mode', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        inputPath: '/videos/source.mp4',
        fileName: 'source.mp4',
        sourceFileSize: 100000000,
        config: VideoTaskConfig.initial().copyWith(
          videoCodec: VideoCodec.h264,
          compressionMode: CompressionMode.targetSize,
          targetSizeBytes: 50000000,
        ),
        analysisResult: MediaAnalysisResult(
          videoHeight: 1080,
          videoBitrate: 5000000,
          audioBitrate: 192000,
          durationMs: 100000,
        ),
      );

      final plan = builder.build(task);

      expect(plan.steps, hasLength(2));
      expect(plan.steps.first.args, containsAllInOrder(['-pass', '1']));
      expect(plan.steps.first.args, containsAllInOrder(['-an', '-f', 'null']));
      expect(plan.steps.first.outputPath, isNull);
      expect(plan.args, isNot(contains('-crf')));
      expect(plan.args, containsAllInOrder(['-b:v', '3872k']));
      expect(plan.args, containsAllInOrder(['-pass', '2']));
      expect(plan.args, containsAllInOrder(['-b:a', '128k']));
      expect(plan.logHint, contains('指定目标体积两遍压缩策略'));
    });

    test('strict target size keeps very low requested bitrate', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        inputPath: '/videos/source.mp4',
        fileName: 'source.mp4',
        sourceFileSize: 105 * 1024 * 1024,
        config: VideoTaskConfig.initial().copyWith(
          videoCodec: VideoCodec.h264,
          compressionMode: CompressionMode.targetSize,
          targetSizeBytes: 10 * 1024 * 1024,
          resolutionPreset: ResolutionPreset.p720,
        ),
        analysisResult: MediaAnalysisResult(
          videoHeight: 1080,
          videoBitrate: 654000,
          audioBitrate: 118000,
          audioCodec: 'aac',
          durationMs: 1125000,
        ),
      );

      final plan = builder.build(task);

      expect(plan.steps, hasLength(2));
      expect(plan.args, isNot(contains('-crf')));
      expect(plan.args, containsAllInOrder(['-b:v', '51k']));
      expect(plan.args, containsAllInOrder(['-pass', '2']));
      expect(plan.args, containsAllInOrder(['-b:a', '24k']));
      expect(plan.args, isNot(contains('500k')));
    });

    test('requires confirmation before building low bitrate compression', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        analysisResult: MediaAnalysisResult(
          videoHeight: 1080,
          videoBitrate: 550000,
        ),
      );

      expect(
        () => builder.build(task),
        throwsA(isA<CompressionConfirmationRequiredException>()),
      );
    });

    test('builds conversion command with selected output format', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        inputPath: '/videos/source.mp4',
        fileName: 'source.mp4',
        purpose: TaskPurpose.conversion,
        config: VideoTaskConfig.initial().copyWith(
          outputFormat: OutputFormat.mkv,
          outputDirectory: '/exports',
          videoCodec: VideoCodec.h264,
        ),
      );

      final plan = builder.build(task);

      expect(plan.outputPath, '/exports/source_converted.mkv');
      expect(plan.args, containsAllInOrder(['-c:v', 'libx264']));
      expect(plan.args, isNot(contains('-movflags')));
    });

    test('uses source directory when output directory is empty', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        inputPath: '/input/folder/demo.mp4',
        fileName: 'demo.mp4',
      );

      final plan = builder.build(task);

      expect(plan.outputPath, '/input/folder/demo_compressed.mp4');
    });

    test('uses custom output file name with selected format extension', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        inputPath: '/input/folder/demo.mov',
        fileName: 'demo.mov',
        config: VideoTaskConfig.initial().copyWith(
          outputFormat: OutputFormat.mkv,
          outputDirectory: '/exports',
          outputFileName: 'final-cut.mp4',
          videoCodec: VideoCodec.h264,
        ),
      );

      final plan = builder.build(task);

      expect(plan.outputPath, '/exports/final-cut.mkv');
      expect(plan.args.last, '/exports/final-cut.mkv');
    });

    test('adds numeric suffix when output path already exists', () {
      final existingPaths = {
        '/videos/source_compressed.mp4',
        '/videos/source_compressed-1.mp4',
      };
      final builder = DefaultFfmpegCommandBuilder(
        pathExists: existingPaths.contains,
      );
      final task = videoTask(inputPath: '/videos/source.mov');

      final plan = builder.build(task);

      expect(plan.outputPath, '/videos/source_compressed-2.mp4');
    });

    test('adds scale args when resolution preset is not original', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        inputPath: '/videos/source.mp4',
        config: VideoTaskConfig.initial().copyWith(
          resolutionPreset: ResolutionPreset.p720,
          videoCodec: VideoCodec.h264,
        ),
      );

      final plan = builder.build(task);

      expect(plan.args, containsAllInOrder(['-vf', 'scale=-2:720']));
    });

    test('builds preview segment without progress output', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        inputPath: '/videos/source.mp4',
        fileName: 'source.mp4',
        analysisResult: MediaAnalysisResult(
          videoHeight: 1080,
          videoBitrate: 3000000,
        ),
      );

      final plan = builder.buildPreviewSegment(
        task,
        startSeconds: 12.34,
        durationSeconds: 1,
        outputPath: '/tmp/preview.mp4',
      );

      expect(plan.outputPath, '/tmp/preview.mp4');
      expect(plan.args, containsAllInOrder(['-ss', '12.340', '-t', '1.000']));
      expect(plan.args, containsAllInOrder(['-c:v', 'libx264']));
      expect(plan.args, isNot(contains('-progress')));
      expect(plan.args.last, '/tmp/preview.mp4');
    });

    test('keeps source HEVC codec when codec is source', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        inputPath: '/videos/source.mp4',
        fileName: 'source.mp4',
        config: VideoTaskConfig.initial().copyWith(
          videoCodec: VideoCodec.source,
        ),
        analysisResult: MediaAnalysisResult(
          videoCodec: 'hevc',
          videoHeight: 2160,
          videoBitrate: 30000000,
        ),
      );

      final plan = builder.build(task);

      expect(plan.args, containsAllInOrder(['-c:v', 'libx265']));
      expect(plan.args, containsAllInOrder(['-tag:v', 'hvc1']));
      expect(plan.logHint, contains('HEVC'));
    });

    test('uses explicit HEVC codec even when source is H.264', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        inputPath: '/videos/source.mp4',
        fileName: 'source.mp4',
        config: VideoTaskConfig.initial().copyWith(videoCodec: VideoCodec.hevc),
        analysisResult: MediaAnalysisResult(
          videoCodec: 'h264',
          videoHeight: 1080,
          videoBitrate: 3000000,
        ),
      );

      final plan = builder.build(task);

      expect(plan.args, containsAllInOrder(['-c:v', 'libx265']));
      expect(plan.args, containsAllInOrder(['-tag:v', 'hvc1']));
    });

    test('smart auto prefers available hardware encoder', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        config: VideoTaskConfig.initial().copyWith(
          videoCodec: VideoCodec.h264,
          encoderBackend: EncoderBackend.auto,
        ),
        analysisResult: MediaAnalysisResult(
          videoHeight: 1080,
          videoBitrate: 3000000,
        ),
      );

      final plan = builder.build(
        task,
        encoderCapabilities: const FfmpegEncoderCapabilities(
          encoderNames: {'libx264', 'libx265', 'h264_videotoolbox'},
          autoBackendPriority: [EncoderBackend.videotoolbox],
        ),
      );

      expect(plan.args, containsAllInOrder(['-c:v', 'h264_videotoolbox']));
      expect(plan.args, containsAllInOrder(['-b:v', '2064k']));
      expect(plan.args, isNot(contains('-crf')));
    });

    test('configured hardware smart mode uses a capped bitrate', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        config: VideoTaskConfig.initial().copyWith(
          videoCodec: VideoCodec.h264,
          encoderBackend: EncoderBackend.videotoolbox,
        ),
        analysisResult: MediaAnalysisResult(
          videoHeight: 1080,
          videoBitrate: 3000000,
        ),
      );

      final plan = builder.build(
        task,
        encoderCapabilities: const FfmpegEncoderCapabilities(
          encoderNames: {'libx264', 'h264_videotoolbox'},
          autoBackendPriority: [EncoderBackend.videotoolbox],
        ),
      );

      expect(plan.args, containsAllInOrder(['-c:v', 'h264_videotoolbox']));
      expect(plan.args, containsAllInOrder(['-b:v', '2064k']));
      expect(plan.args, isNot(contains('-crf')));
    });

    test(
      'smart auto falls back to capped hardware when HEVC software is absent',
      () {
        final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
        final task = videoTask(
          inputPath: '/videos/dji.mp4',
          config: VideoTaskConfig.initial().copyWith(
            videoCodec: VideoCodec.hevc,
            encoderBackend: EncoderBackend.auto,
            resolutionPreset: ResolutionPreset.p720,
            smartPreset: SmartCompressionPreset.compact,
            compressionCrf: 32,
          ),
          analysisResult: MediaAnalysisResult(
            videoHeight: 2160,
            videoBitrate: 90000000,
            audioBitrate: 317000,
          ),
        );

        final plan = builder.build(
          task,
          encoderCapabilities: const FfmpegEncoderCapabilities(
            encoderNames: {'libx264', 'hevc_videotoolbox'},
            autoBackendPriority: [EncoderBackend.videotoolbox],
          ),
        );

        expect(plan.args, containsAllInOrder(['-c:v', 'hevc_videotoolbox']));
        expect(plan.args, containsAllInOrder(['-b:v', '792k']));
        expect(plan.args, isNot(contains('62896k')));
      },
    );

    test('target size auto prefers available hardware encoder', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        sourceFileSize: 100000000,
        config: VideoTaskConfig.initial().copyWith(
          videoCodec: VideoCodec.h264,
          encoderBackend: EncoderBackend.auto,
          compressionMode: CompressionMode.targetSize,
          targetSizeBytes: 50000000,
        ),
        analysisResult: MediaAnalysisResult(
          videoHeight: 1080,
          videoBitrate: 5000000,
          durationMs: 100000,
        ),
      );

      final plan = builder.build(
        task,
        encoderCapabilities: const FfmpegEncoderCapabilities(
          encoderNames: {'libx264', 'h264_videotoolbox'},
          autoBackendPriority: [EncoderBackend.videotoolbox],
        ),
      );

      expect(plan.steps, hasLength(1));
      expect(plan.args, containsAllInOrder(['-c:v', 'h264_videotoolbox']));
      expect(plan.args, isNot(contains('libx264')));
    });

    test('smart auto prefers HEVC Windows hardware before software', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        config: VideoTaskConfig.initial().copyWith(
          videoCodec: VideoCodec.hevc,
          encoderBackend: EncoderBackend.auto,
        ),
        analysisResult: MediaAnalysisResult(
          videoHeight: 1080,
          videoBitrate: 3000000,
        ),
      );

      final plan = builder.build(
        task,
        encoderCapabilities: const FfmpegEncoderCapabilities(
          encoderNames: {'libx264', 'libx265', 'hevc_qsv', 'hevc_amf'},
          autoBackendPriority: [
            EncoderBackend.nvenc,
            EncoderBackend.qsv,
            EncoderBackend.amf,
          ],
        ),
      );

      expect(plan.args, containsAllInOrder(['-c:v', 'hevc_qsv']));
      expect(plan.args, containsAllInOrder(['-b:v', '2064k']));
      expect(plan.args, containsAllInOrder(['-tag:v', 'hvc1']));
    });

    test('rejects non-video tasks', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        inputPath: '/images/source.png',
        fileName: 'source.png',
        mediaKind: MediaKind.image,
      );

      expect(
        () => builder.build(task),
        throwsA(isA<FfmpegCommandBuildException>()),
      );
    });

    test('rejects incompatible encoder backend', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        config: VideoTaskConfig.initial().copyWith(
          videoCodec: VideoCodec.hevc,
          encoderBackend: EncoderBackend.libx264,
        ),
      );

      expect(
        () => builder.build(task),
        throwsA(isA<FfmpegCommandBuildException>()),
      );
    });

    test('rejects explicitly selected unsupported hardware backend', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        config: VideoTaskConfig.initial().copyWith(
          videoCodec: VideoCodec.h264,
          encoderBackend: EncoderBackend.nvenc,
        ),
      );

      expect(
        () => builder.build(task),
        throwsA(isA<FfmpegCommandBuildException>()),
      );
    });
  });
}

MediaTask videoTask({
  String inputPath = '/videos/source.mov',
  String fileName = 'source.mov',
  MediaKind mediaKind = MediaKind.video,
  TaskPurpose purpose = TaskPurpose.compression,
  VideoTaskConfig? config,
  MediaAnalysisResult? analysisResult,
  int? sourceFileSize,
}) {
  var task = MediaTask(
    id: 'task-1',
    inputPath: inputPath,
    fileName: fileName,
    mediaKind: mediaKind,
    purpose: purpose,
    status: TaskStatus.pending,
    config:
        config ??
        VideoTaskConfig.initial().copyWith(videoCodec: VideoCodec.h264),
    progress: 0,
    sortOrder: 0,
    createdAt: 1,
    analysisResult: analysisResult,
  );

  if (sourceFileSize != null) {
    task = task.withSourceFileFingerprint(
      SourceFileFingerprint(fileSize: sourceFileSize, lastModifiedAt: 1),
    );
  }

  return task;
}
