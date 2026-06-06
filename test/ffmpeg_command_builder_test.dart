import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/source_file_fingerprint.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/default_ffmpeg_command_builder.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_output_path_builder.dart';

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
          audioCodec: 'aac',
          audioStreamIndex: 1,
        ),
      );

      final plan = builder.build(task);

      expect(plan.outputPath, '/videos/source_compressed.mp4');
      expect(plan.args, [
        '-hide_banner',
        '-i',
        '/videos/source.mov',
        '-map',
        '0:v:0',
        '-map',
        '0:1?',
        '-map_metadata',
        '0:g',
        '-map_chapters',
        '0',
        '-c:v',
        'libx264',
        '-preset',
        'slow',
        '-crf',
        '28',
        '-vf',
        'scale=trunc(iw/2)*2:trunc(ih/2)*2:flags=lanczos:'
            'in_range=auto:out_range=tv:'
            'in_color_matrix=auto:out_color_matrix=bt709,'
            'format=yuv420p,setsar=1',
        '-pix_fmt',
        'yuv420p',
        '-color_range',
        'tv',
        '-colorspace',
        'bt709',
        '-color_trc',
        'bt709',
        '-color_primaries',
        'bt709',
        '-profile:v',
        'high',
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
      expect(plan.args, contains('-vf'));
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
      expect(plan.args, containsAllInOrder(['-ac', '1']));
      expect(plan.args, isNot(contains('500k')));
    });

    test('preserves compatible audio shape when source audio is known', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        analysisResult: MediaAnalysisResult(
          videoHeight: 1080,
          videoBitrate: 3000000,
          audioCodec: 'aac',
          audioBitrate: 192000,
          audioChannels: 6,
          audioSampleRate: 44100,
        ),
      );

      final plan = builder.build(task);

      expect(plan.args, containsAllInOrder(['-c:a', 'aac']));
      expect(plan.args, containsAllInOrder(['-ac', '2']));
      expect(plan.args, containsAllInOrder(['-ar', '44100']));
    });

    test('uses native AAC even when the runtime exposes AudioToolbox AAC', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        analysisResult: MediaAnalysisResult(
          videoHeight: 1080,
          videoBitrate: 3000000,
          audioCodec: 'aac',
          audioBitrate: 192000,
          audioChannels: 2,
          audioSampleRate: 48000,
        ),
      );

      final plan = builder.build(
        task,
        encoderCapabilities: const FfmpegEncoderCapabilities(
          encoderNames: {'libx264', 'aac', 'aac_at'},
          autoBackendPriority: [],
        ),
      );

      expect(plan.args, containsAllInOrder(['-c:a', 'aac']));
      expect(plan.args, isNot(contains('aac_at')));
      expect(plan.args, isNot(contains('-aac_at_mode')));
      expect(plan.args, isNot(contains('-aac_at_quality')));
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

    test(
      'adds numeric suffix when MOV output differs from source only by case',
      () {
        final builder = DefaultFfmpegCommandBuilder(
          outputPathBuilder: FfmpegOutputPathBuilder(
            pathExists: (_) => false,
            caseInsensitiveFileSystem: true,
          ),
        );
        final task = videoTask(
          inputPath: '/videos/clip.MOV',
          fileName: 'clip.MOV',
          config: VideoTaskConfig.initial().copyWith(
            outputFormat: OutputFormat.mov,
            outputFileName: 'clip.MOV',
            videoCodec: VideoCodec.h264,
          ),
        );

        final plan = builder.build(task);

        expect(plan.outputPath, '/videos/clip-1.mov');
        expect(plan.args.last, '/videos/clip-1.mov');
      },
    );

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

      expect(
        plan.args,
        containsAllInOrder([
          '-vf',
          'scale=-2:trunc(min(720\\,ih)/2)*2:flags=lanczos:'
              'in_range=auto:out_range=tv:'
              'in_color_matrix=auto:out_color_matrix=bt709,'
              'format=yuv420p,setsar=1',
        ]),
      );
    });

    test('uses VideoToolbox HDR to SDR scale filter for HDR sources', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        inputPath: '/videos/hdr.mov',
        fileName: 'hdr.mov',
        config: VideoTaskConfig.initial().copyWith(
          videoCodec: VideoCodec.hevc,
          encoderBackend: EncoderBackend.videotoolbox,
          resolutionPreset: ResolutionPreset.p1080,
        ),
        analysisResult: MediaAnalysisResult(
          videoHeight: 2160,
          videoCodec: 'hevc',
          videoBitrate: 30000000,
          colorSpace: 'bt2020nc',
          colorTransfer: 'smpte2084',
          colorPrimaries: 'bt2020',
        ),
      );

      final plan = builder.build(
        task,
        encoderCapabilities: const FfmpegEncoderCapabilities(
          encoderNames: {'libx264', 'hevc_videotoolbox'},
          autoBackendPriority: [EncoderBackend.videotoolbox],
        ),
      );

      expect(
        plan.args,
        containsAllInOrder([
          '-vf',
          'scale_vt=w=-2:h=trunc(min(1080\\,ih)/2)*2:'
              'color_matrix=bt709:color_primaries=bt709:'
              'color_transfer=bt709,format=yuv420p,setsar=1',
        ]),
      );
      expect(plan.args, containsAllInOrder(['-color_trc', 'bt709']));
      expect(plan.args, containsAllInOrder(['-tag:v', 'hvc1']));
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

    test('treats hvc1 source codec as HEVC when codec is source', () {
      // iPhone .MOV files report codec_name as 'hvc1' via ffprobe
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        inputPath: '/videos/IMG_8079.MOV',
        fileName: 'IMG_8079.MOV',
        config: VideoTaskConfig.initial().copyWith(
          videoCodec: VideoCodec.source,
        ),
        analysisResult: MediaAnalysisResult(
          videoCodec: 'hvc1',
          videoHeight: 1080,
          videoBitrate: 10000000,
        ),
      );

      final plan = builder.build(task);

      expect(plan.args, containsAllInOrder(['-c:v', 'libx265']));
      expect(plan.args, containsAllInOrder(['-tag:v', 'hvc1']));
      expect(plan.logHint, contains('HEVC'));
    });

    test('maps only the primary usable audio stream for iPhone MOV', () {
      // iPhone .MOV files may contain Apple Positional Audio as an audio stream
      // with codec_name=none. Mapping all audio streams makes FFmpeg try to
      // decode that unsupported stream, so command construction maps the
      // FFprobe-selected usable audio stream by global stream index.
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        inputPath: '/videos/IMG_8079.MOV',
        fileName: 'IMG_8079.MOV',
        analysisResult: MediaAnalysisResult(
          videoHeight: 1080,
          videoBitrate: 10000000,
          audioCodec: 'aac',
          audioStreamIndex: 1,
        ),
      );

      final plan = builder.build(task);

      expect(plan.args, containsAllInOrder(['-map', '0:v:0']));
      expect(plan.args, containsAllInOrder(['-map', '0:1?']));
      expect(plan.args, isNot(contains('0:a?')));
      expect(plan.args, containsAllInOrder(['-map_metadata', '0:g']));
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

    test('smart auto uses software for high-risk iPhone HDR MOV', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = videoTask(
        inputPath: '/videos/IMG_8079.MOV',
        fileName: 'IMG_8079.MOV',
        config: VideoTaskConfig.initial().copyWith(
          videoCodec: VideoCodec.h264,
          encoderBackend: EncoderBackend.auto,
          resolutionPreset: ResolutionPreset.p1080,
        ),
        analysisResult: MediaAnalysisResult(
          videoCodec: 'hvc1',
          videoHeight: 2160,
          videoBitrate: 30000000,
          videoBitDepth: 10,
          colorSpace: 'bt2020nc',
          colorTransfer: 'smpte2084',
          colorPrimaries: 'bt2020',
          containerFormat: 'mov,mp4,m4a,3gp,3g2,mj2',
          audioCodec: 'aac',
          audioStreamIndex: 1,
        ),
      );

      final plan = builder.build(
        task,
        encoderCapabilities: const FfmpegEncoderCapabilities(
          encoderNames: {'libx264', 'h264_videotoolbox', 'aac'},
          autoBackendPriority: [EncoderBackend.videotoolbox],
        ),
      );

      expect(plan.args, containsAllInOrder(['-c:v', 'libx264']));
      expect(plan.args, isNot(contains('h264_videotoolbox')));
      expect(plan.args, containsAllInOrder(['-map', '0:1?']));
      expect(plan.args, containsAllInOrder(['-c:a', 'aac']));
      expect(
        plan.args,
        containsAllInOrder([
          '-vf',
          'scale=-2:trunc(min(1080\\,ih)/2)*2:flags=lanczos:'
              'in_range=auto:out_range=tv:'
              'in_color_matrix=auto:out_color_matrix=bt709,'
              'format=yuv420p,setsar=1',
        ]),
      );
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

    test('builds image processing command with step progress', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = MediaTask(
        id: 'task-image',
        inputPath: '/images/source.png',
        fileName: 'source.png',
        mediaKind: MediaKind.image,
        purpose: TaskPurpose.compression,
        status: TaskStatus.pending,
        config: MediaTaskConfig.initialImage().copyWith(
          image: ImageProcessingConfig.initial().copyWith(
            outputFormat: MediaOutputFormat.webp,
            imageQuality: 76,
            resizePreset: ImageResizePreset.longEdge1920,
          ),
        ),
        progress: 0,
        sortOrder: 0,
        createdAt: 1,
      );

      final plan = builder.build(task);

      expect(plan.outputPath, '/images/source_compressed.webp');
      expect(plan.steps, hasLength(1));
      expect(plan.steps.single.progressMode, ProgressMode.step);
      expect(plan.args, containsAllInOrder(['-i', '/images/source.png']));
      expect(plan.args, contains('-vf'));
      expect(plan.args, containsAllInOrder(['-c:v', 'libwebp']));
      expect(plan.args, containsAllInOrder(['-quality', '76']));
      expect(plan.args, containsAllInOrder(['-map_metadata', '-1']));
      expect(plan.args.last, '/images/source_compressed.webp');
    });

    test('rejects WebP output when FFmpeg lacks libwebp', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = MediaTask(
        id: 'task-image',
        inputPath: '/images/source.png',
        fileName: 'source.png',
        mediaKind: MediaKind.image,
        purpose: TaskPurpose.compression,
        status: TaskStatus.pending,
        config: MediaTaskConfig.initialImage().copyWith(
          image: ImageProcessingConfig.initial().copyWith(
            outputFormat: MediaOutputFormat.webp,
          ),
        ),
        progress: 0,
        sortOrder: 0,
        createdAt: 1,
      );

      expect(
        () => builder.build(
          task,
          encoderCapabilities: const FfmpegEncoderCapabilities(
            encoderNames: {'libx264', 'aac'},
            autoBackendPriority: [],
          ),
        ),
        throwsA(
          isA<FfmpegCommandBuildException>()
              .having((error) => error.message, 'message', contains('WebP'))
              .having((error) => error.message, 'message', contains('libwebp')),
        ),
      );
    });

    test('preserves image metadata when requested', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = MediaTask(
        id: 'task-image',
        inputPath: '/images/source.jpg',
        fileName: 'source.jpg',
        mediaKind: MediaKind.image,
        purpose: TaskPurpose.compression,
        status: TaskStatus.pending,
        config: MediaTaskConfig.initialImage().copyWith(
          image: ImageProcessingConfig.initial().copyWith(
            preserveMetadata: true,
          ),
        ),
        progress: 0,
        sortOrder: 0,
        createdAt: 1,
      );

      final plan = builder.build(task);

      expect(plan.args, isNot(contains('-map_metadata')));
    });

    test('builds image commands for bitmap, tiff, and gif outputs', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);

      MediaTask imageTask(MediaOutputFormat outputFormat) {
        return MediaTask(
          id: 'task-image-${outputFormat.name}',
          inputPath: '/images/source.png',
          fileName: 'source.png',
          mediaKind: MediaKind.image,
          purpose: TaskPurpose.conversion,
          status: TaskStatus.pending,
          config: MediaTaskConfig.initialImage().copyWith(
            image: ImageProcessingConfig.initial().copyWith(
              outputFormat: outputFormat,
            ),
          ),
          progress: 0,
          sortOrder: 0,
          createdAt: 1,
        );
      }

      final bmpPlan = builder.build(imageTask(MediaOutputFormat.bmp));
      expect(bmpPlan.outputPath, '/images/source_converted.bmp');
      expect(bmpPlan.args, containsAllInOrder(['-c:v', 'bmp']));

      final tiffPlan = builder.build(imageTask(MediaOutputFormat.tiff));
      expect(tiffPlan.outputPath, '/images/source_converted.tiff');
      expect(tiffPlan.args, containsAllInOrder(['-c:v', 'tiff']));

      final gifPlan = builder.build(imageTask(MediaOutputFormat.gif));
      expect(gifPlan.outputPath, '/images/source_converted.gif');
      expect(gifPlan.args, containsAllInOrder(['-c:v', 'gif']));
    });

    test('rejects image tasks with non-image output format', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = MediaTask(
        id: 'task-image',
        inputPath: '/images/source.png',
        fileName: 'source.png',
        mediaKind: MediaKind.image,
        purpose: TaskPurpose.conversion,
        status: TaskStatus.pending,
        config: MediaTaskConfig.initialImage().copyWith(
          image: ImageProcessingConfig.initial().copyWith(
            outputFormat: MediaOutputFormat.mp3,
          ),
        ),
        progress: 0,
        sortOrder: 0,
        createdAt: 1,
      );

      expect(
        () => builder.build(task),
        throwsA(isA<FfmpegCommandBuildException>()),
      );
    });

    test('builds audio processing command', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = MediaTask(
        id: 'task-audio',
        inputPath: '/audio/source.wav',
        fileName: 'source.wav',
        mediaKind: MediaKind.audio,
        purpose: TaskPurpose.compression,
        status: TaskStatus.pending,
        config: MediaTaskConfig.initialAudio().copyWith(
          audio: AudioProcessingConfig.initial().copyWith(
            outputFormat: MediaOutputFormat.mp3,
            bitratePreset: AudioBitratePreset.k128,
            sampleRate: AudioSampleRatePreset.hz44100,
            channels: AudioChannelsPreset.stereo,
          ),
        ),
        progress: 0,
        sortOrder: 0,
        createdAt: 1,
      );

      final plan = builder.build(task);

      expect(plan.outputPath, '/audio/source_compressed.mp3');
      expect(plan.steps, hasLength(1));
      expect(plan.args, containsAllInOrder(['-i', '/audio/source.wav']));
      expect(plan.args, contains('-vn'));
      expect(plan.args, containsAllInOrder(['-c:a', 'libmp3lame']));
      expect(plan.args, containsAllInOrder(['-b:a', '128k']));
      expect(plan.args, containsAllInOrder(['-ar', '44100']));
      expect(plan.args, containsAllInOrder(['-ac', '2']));
      expect(plan.args, containsAllInOrder(['-progress', 'pipe:1']));
      expect(plan.args.last, '/audio/source_compressed.mp3');
    });

    test('rejects MP3 output when FFmpeg lacks libmp3lame', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = MediaTask(
        id: 'task-audio',
        inputPath: '/audio/source.wav',
        fileName: 'source.wav',
        mediaKind: MediaKind.audio,
        purpose: TaskPurpose.compression,
        status: TaskStatus.pending,
        config: MediaTaskConfig.initialAudio().copyWith(
          audio: AudioProcessingConfig.initial().copyWith(
            outputFormat: MediaOutputFormat.mp3,
          ),
        ),
        progress: 0,
        sortOrder: 0,
        createdAt: 1,
      );

      expect(
        () => builder.build(
          task,
          encoderCapabilities: const FfmpegEncoderCapabilities(
            encoderNames: {'aac', 'pcm_s16le', 'flac'},
            autoBackendPriority: [],
          ),
        ),
        throwsA(
          isA<FfmpegCommandBuildException>()
              .having((error) => error.message, 'message', contains('MP3'))
              .having(
                (error) => error.message,
                'message',
                contains('libmp3lame'),
              ),
        ),
      );
    });

    test('builds audio commands for AIFF and WMA outputs', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);

      MediaTask audioTask(MediaOutputFormat outputFormat) {
        return MediaTask(
          id: 'task-audio-${outputFormat.name}',
          inputPath: '/audio/source.wav',
          fileName: 'source.wav',
          mediaKind: MediaKind.audio,
          purpose: TaskPurpose.conversion,
          status: TaskStatus.pending,
          config: MediaTaskConfig.initialAudio().copyWith(
            audio: AudioProcessingConfig.initial().copyWith(
              outputFormat: outputFormat,
            ),
          ),
          progress: 0,
          sortOrder: 0,
          createdAt: 1,
        );
      }

      final aiffPlan = builder.build(audioTask(MediaOutputFormat.aiff));
      expect(aiffPlan.outputPath, '/audio/source_converted.aiff');
      expect(aiffPlan.args, containsAllInOrder(['-c:a', 'pcm_s16be']));

      final wmaPlan = builder.build(audioTask(MediaOutputFormat.wma));
      expect(wmaPlan.outputPath, '/audio/source_converted.wma');
      expect(wmaPlan.args, containsAllInOrder(['-c:a', 'wmav2']));
    });

    test('builds audio commands for Opus outputs', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);

      MediaTask audioTask(MediaOutputFormat outputFormat) {
        return MediaTask(
          id: 'task-audio-${outputFormat.name}',
          inputPath: '/audio/source.wav',
          fileName: 'source.wav',
          mediaKind: MediaKind.audio,
          purpose: TaskPurpose.conversion,
          status: TaskStatus.pending,
          config: MediaTaskConfig.initialAudio().copyWith(
            audio: AudioProcessingConfig.initial().copyWith(
              outputFormat: outputFormat,
            ),
          ),
          progress: 0,
          sortOrder: 0,
          createdAt: 1,
        );
      }

      final opusPlan = builder.build(audioTask(MediaOutputFormat.opus));
      expect(opusPlan.outputPath, '/audio/source_converted.opus');
      expect(opusPlan.args, containsAllInOrder(['-c:a', 'libopus']));

      final oggOpusPlan = builder.build(audioTask(MediaOutputFormat.oggOpus));
      expect(oggOpusPlan.outputPath, '/audio/source_converted.ogg');
      expect(oggOpusPlan.args, containsAllInOrder(['-c:a', 'libopus']));
    });

    test('rejects audio tasks with non-audio output format', () {
      final builder = DefaultFfmpegCommandBuilder(pathExists: (_) => false);
      final task = MediaTask(
        id: 'task-audio',
        inputPath: '/audio/source.wav',
        fileName: 'source.wav',
        mediaKind: MediaKind.audio,
        purpose: TaskPurpose.conversion,
        status: TaskStatus.pending,
        config: MediaTaskConfig.initialAudio().copyWith(
          audio: AudioProcessingConfig.initial().copyWith(
            outputFormat: MediaOutputFormat.jpg,
          ),
        ),
        progress: 0,
        sortOrder: 0,
        createdAt: 1,
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
