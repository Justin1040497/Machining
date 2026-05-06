import 'package:flutter_test/flutter_test.dart';
import 'package:machining/application/services/ffmpeg_command_builder.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/encoder_backend.dart';
import 'package:machining/domain/enums/media_kind.dart';
import 'package:machining/domain/enums/output_format.dart';
import 'package:machining/domain/enums/resolution_preset.dart';
import 'package:machining/domain/enums/task_purpose.dart';
import 'package:machining/domain/enums/task_status.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';
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
        '128k',
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
  });
}

MediaTask videoTask({
  String inputPath = '/videos/source.mov',
  String fileName = 'source.mov',
  MediaKind mediaKind = MediaKind.video,
  TaskPurpose purpose = TaskPurpose.compression,
  VideoTaskConfig? config,
  MediaAnalysisResult? analysisResult,
}) {
  return MediaTask(
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
}
