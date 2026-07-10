import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/use_cases/media_tasks/media_task_use_case_helpers.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/output_location_mode.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/video_processing_config.dart';

void main() {
  test('encoder file name tokens use canonical names', () {
    expect(
      videoEncoderBackendFileNameToken(
        backend: EncoderBackend.auto,
        videoCodec: VideoCodec.h264,
      ),
      'x264',
    );
    expect(
      videoEncoderBackendFileNameToken(
        backend: EncoderBackend.auto,
        videoCodec: VideoCodec.hevc,
      ),
      'x265',
    );
    expect(
      videoEncoderBackendFileNameToken(
        backend: EncoderBackend.libx264,
        videoCodec: VideoCodec.h264,
      ),
      'x264',
    );
    expect(
      videoEncoderBackendFileNameToken(
        backend: EncoderBackend.libx265,
        videoCodec: VideoCodec.hevc,
      ),
      'x265',
    );
    expect(
      videoEncoderBackendFileNameToken(
        backend: EncoderBackend.videotoolbox,
        videoCodec: VideoCodec.h264,
      ),
      'videotoolbox',
    );
    expect(
      videoEncoderBackendFileNameToken(
        backend: EncoderBackend.nvenc,
        videoCodec: VideoCodec.h264,
      ),
      'nvenc',
    );
    expect(
      videoEncoderBackendFileNameToken(
        backend: EncoderBackend.qsv,
        videoCodec: VideoCodec.h264,
      ),
      'qsv',
    );
    expect(
      videoEncoderBackendFileNameToken(
        backend: EncoderBackend.amf,
        videoCodec: VideoCodec.h264,
      ),
      'amf',
    );
  });

  group('buildInitialTaskConfigFromSettings', () {
    test('uses image defaults from app media config', () {
      final settings = AppSettings.initial().copyWith(
        defaultOutputDirectory: '/tmp/output',
        saveOutputToSourceDirectory: false,
        defaultMediaConfig: MediaTaskConfig.initialDefaults().copyWith(
          image: ImageProcessingConfig.initial().copyWith(imageQuality: 61),
        ),
      );

      final config = buildInitialTaskConfigFromSettings(
        sourceFileName: 'photo.png',
        mediaKind: MediaKind.image,
        settings: settings,
        now: DateTime(2026),
      );

      expect(config.outputLocationMode, OutputLocationMode.system);
      expect(config.outputDirectory, isEmpty);
      expect(config.outputFileName, 'photo-处理');
      expect(config.video, isNull);
      expect(config.audio, isNull);
      expect(config.image?.imageQuality, 61);
    });

    test('uses audio defaults from app media config', () {
      final settings = AppSettings.initial().copyWith(
        defaultMediaConfig: MediaTaskConfig.initialDefaults().copyWith(
          audio: AudioProcessingConfig.initial().copyWith(
            bitratePreset: AudioBitratePreset.k128,
          ),
        ),
      );

      final config = buildInitialTaskConfigFromSettings(
        sourceFileName: 'track.wav',
        mediaKind: MediaKind.audio,
        settings: settings,
        now: DateTime(2026),
      );

      expect(config.outputDirectory, isEmpty);
      expect(config.outputFileName, 'track-处理');
      expect(config.video, isNull);
      expect(config.image, isNull);
      expect(config.audio?.bitratePreset, AudioBitratePreset.k128);
    });

    test('renders the video codec token', () {
      final settings = AppSettings.initial().copyWith(
        defaultOutputVideoCodec: VideoCodec.hevc,
        defaultOutputFileNameTemplate: '{source}-{codec}',
      );

      final config = buildInitialTaskConfigFromSettings(
        sourceFileName: 'holiday.mov',
        mediaKind: MediaKind.video,
        settings: settings,
        now: DateTime(2026, 6, 12),
      );

      expect(config.outputFileName, 'holiday-h265');
    });

    test('renders encoder token without duplicate x prefixes', () {
      final settings = AppSettings.initial().copyWith(
        defaultOutputFileNameTemplate: '{source}-x{codec}-x{encoder}-1920x1080',
        defaultMediaConfig: MediaTaskConfig.initialDefaults().copyWith(
          video: VideoProcessingConfig.initial().copyWith(
            videoCodec: VideoCodec.hevc,
            encoderBackend: EncoderBackend.libx265,
          ),
        ),
      );

      final config = buildInitialTaskConfigFromSettings(
        sourceFileName: 'holiday.mov',
        mediaKind: MediaKind.video,
        settings: settings,
        now: DateTime(2026, 6, 12),
      );

      expect(config.outputFileName, 'holiday-h265-x265-1920×1080');
    });

    test('resolves keep-original output formats from source file names', () {
      final settings = AppSettings.initial().copyWith(
        defaultOutputFileNameTemplate: '{source}-{codec}',
        defaultMediaConfig: MediaTaskConfig.initialDefaults().copyWith(
          video: VideoProcessingConfig.initial().copyWith(
            keepOriginalOutputFormat: true,
          ),
          image: ImageProcessingConfig.initial().copyWith(
            keepOriginalOutputFormat: true,
          ),
          audio: AudioProcessingConfig.initial().copyWith(
            keepOriginalOutputFormat: true,
          ),
        ),
      );

      final videoConfig = buildInitialTaskConfigFromSettings(
        sourceFileName: 'clip.MP4',
        mediaKind: MediaKind.video,
        settings: settings,
        now: DateTime(2026, 6, 12),
      );
      final imageConfig = buildInitialTaskConfigFromSettings(
        sourceFileName: 'cover.PNG',
        mediaKind: MediaKind.image,
        settings: settings,
        now: DateTime(2026, 6, 12),
      );
      final audioConfig = buildInitialTaskConfigFromSettings(
        sourceFileName: 'voice.ogg',
        mediaKind: MediaKind.audio,
        settings: settings,
        now: DateTime(2026, 6, 12),
      );

      expect(videoConfig.video?.outputFormat, MediaOutputFormat.mp4);
      expect(videoConfig.video?.keepOriginalOutputFormat, isTrue);
      expect(imageConfig.image?.outputFormat, MediaOutputFormat.png);
      expect(imageConfig.image?.keepOriginalOutputFormat, isTrue);
      expect(audioConfig.audio?.outputFormat, MediaOutputFormat.oggOpus);
      expect(audioConfig.audio?.keepOriginalOutputFormat, isTrue);
      expect(audioConfig.outputFileName, 'voice-ogg-opus');
    });

    test('renders codec token from image and audio output formats', () {
      final settings = AppSettings.initial().copyWith(
        defaultOutputFileNameTemplate: '{source}-{codec}',
        defaultMediaConfig: MediaTaskConfig.initialDefaults().copyWith(
          image: ImageProcessingConfig.initial().copyWith(
            outputFormat: MediaOutputFormat.webp,
            keepOriginalOutputFormat: false,
          ),
          audio: AudioProcessingConfig.initial().copyWith(
            outputFormat: MediaOutputFormat.oggOpus,
            keepOriginalOutputFormat: false,
          ),
        ),
      );

      final imageConfig = buildInitialTaskConfigFromSettings(
        sourceFileName: 'cover.png',
        mediaKind: MediaKind.image,
        settings: settings,
        now: DateTime(2026, 6, 12),
      );
      final audioConfig = buildInitialTaskConfigFromSettings(
        sourceFileName: 'track.wav',
        mediaKind: MediaKind.audio,
        settings: settings,
        now: DateTime(2026, 6, 12),
      );

      expect(imageConfig.outputFileName, 'cover-webp');
      expect(audioConfig.outputFileName, 'track-ogg-opus');
    });
  });

  group('buildDefaultOutputFileName', () {
    test('renders the default source action template', () {
      final fileName = buildDefaultOutputFileName(
        sourceFileName: 'holiday.mov',
        mediaKind: MediaKind.video,
        template: defaultOutputFileNameTemplatePattern,
        purpose: TaskPurpose.compression,
        now: DateTime(2026, 6, 12),
      );

      expect(fileName, 'holiday-压缩');
    });

    test('uses conversion as the action for conversion tasks', () {
      final fileName = buildDefaultOutputFileName(
        sourceFileName: 'cover.png',
        mediaKind: MediaKind.image,
        template: '{source}-{action}',
        purpose: TaskPurpose.conversion,
        now: DateTime(2026, 6, 12),
      );

      expect(fileName, 'cover-转换');
    });

    test('renders processing version tokens', () {
      final firstVersionFileName = buildDefaultOutputFileName(
        sourceFileName: 'holiday.mov',
        mediaKind: MediaKind.video,
        template: '{source}-{version}',
        purpose: TaskPurpose.compression,
        now: DateTime(2026, 6, 12),
      );
      final secondVersionFileName = buildDefaultOutputFileName(
        sourceFileName: 'holiday.mov',
        mediaKind: MediaKind.video,
        template: '{source}-{version}',
        purpose: TaskPurpose.compression,
        now: DateTime(2026, 6, 12),
        version: 2,
      );

      expect(firstVersionFileName, 'holiday-v1');
      expect(secondVersionFileName, 'holiday-v2');
    });

    test('does not render unsupported variable names', () {
      final fileName = buildDefaultOutputFileName(
        sourceFileName: 'cover.png',
        mediaKind: MediaKind.image,
        template: '{sourceName}-{operation}',
        purpose: TaskPurpose.conversion,
        now: DateTime(2026, 6, 12),
      );

      expect(fileName, 'cover');
    });

    test('sanitizes unsafe filename characters after rendering', () {
      final fileName = buildDefaultOutputFileName(
        sourceFileName: 'clip.mp4',
        mediaKind: MediaKind.video,
        template: r'{source}/{date}:*{action}',
        purpose: TaskPurpose.compression,
        now: DateTime(2026, 6, 12),
      );

      expect(fileName, 'clip-20260612-压缩');
    });
  });

  group('processingVersionForTask', () {
    test('counts repeated imports of the same source and purpose', () {
      final firstTask = testTask(
        id: 'first',
        inputPath: '/videos/holiday.mov',
        createdAt: 1,
        sortOrder: 0,
      );
      final secondTask = testTask(
        id: 'second',
        inputPath: '/videos/holiday.mov',
        createdAt: 2,
        sortOrder: 1,
      );
      final conversionTask = testTask(
        id: 'conversion',
        inputPath: '/videos/holiday.mov',
        purpose: TaskPurpose.conversion,
        createdAt: 3,
        sortOrder: 2,
      );

      expect(
        processingVersionForTask(
          tasks: [firstTask, secondTask, conversionTask],
          inputPath: '/videos/holiday.mov',
          mediaKind: MediaKind.video,
          purpose: TaskPurpose.compression,
        ),
        3,
      );
      expect(
        processingVersionForTask(
          tasks: [secondTask, firstTask],
          inputPath: '/videos/holiday.mov',
          mediaKind: MediaKind.video,
          purpose: TaskPurpose.compression,
          taskId: 'second',
        ),
        2,
      );
      expect(
        processingVersionForTask(
          tasks: [firstTask, secondTask],
          inputPath: '/videos/holiday.mov',
          mediaKind: MediaKind.video,
          purpose: TaskPurpose.conversion,
        ),
        1,
      );
    });
  });
}

MediaTask testTask({
  required String id,
  required String inputPath,
  TaskPurpose purpose = TaskPurpose.compression,
  int createdAt = 1,
  int sortOrder = 0,
}) {
  return MediaTask(
    id: id,
    inputPath: inputPath,
    fileName: 'holiday.mov',
    mediaKind: MediaKind.video,
    purpose: purpose,
    status: TaskStatus.pending,
    config: MediaTaskConfig.initialFor(MediaKind.video),
    progress: 0,
    sortOrder: sortOrder,
    createdAt: createdAt,
  );
}
