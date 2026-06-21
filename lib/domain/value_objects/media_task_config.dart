import 'package:framelean/app/constants.dart';
import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/hdr_output_mode.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/media_processing_preset.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/output_location_mode.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/video_processing_config.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';

const Object _notProvided = Object();

/// 通用媒体任务处理配置，按媒体类型持有分类型配置。
class MediaTaskConfig {
  final OutputLocationMode outputLocationMode;
  final String outputDirectory;
  final String outputFileName;
  final CompressionMode compressionMode;
  final MediaProcessingPreset? preset;
  final int? targetSizeBytes;
  final double? targetSizeRatio;
  final int? threadLimit;
  final VideoProcessingConfig? video;
  final ImageProcessingConfig? image;
  final AudioProcessingConfig? audio;

  const MediaTaskConfig({
    this.outputLocationMode = OutputLocationMode.system,
    required this.outputDirectory,
    required this.outputFileName,
    required this.compressionMode,
    this.preset,
    this.targetSizeBytes,
    this.targetSizeRatio,
    this.threadLimit,
    this.video,
    this.image,
    this.audio,
  });

  factory MediaTaskConfig.initialFor(MediaKind mediaKind) {
    return switch (mediaKind) {
      MediaKind.video => MediaTaskConfig.initialVideo(),
      MediaKind.image => MediaTaskConfig.initialImage(),
      MediaKind.audio => MediaTaskConfig.initialAudio(),
    };
  }

  factory MediaTaskConfig.initialVideo() {
    final video = VideoProcessingConfig.initial();
    return MediaTaskConfig(
      outputLocationMode: OutputLocationMode.system,
      outputDirectory: '',
      outputFileName: '',
      compressionMode: CompressionMode.preset,
      preset: MediaProcessingPreset.smaller,
      targetSizeBytes: null,
      targetSizeRatio: null,
      threadLimit: null,
      video: video,
    );
  }

  factory MediaTaskConfig.initialImage() {
    return MediaTaskConfig(
      outputLocationMode: OutputLocationMode.system,
      outputDirectory: '',
      outputFileName: '',
      compressionMode: CompressionMode.preset,
      preset: MediaProcessingPreset.balanced,
      targetSizeBytes: null,
      targetSizeRatio: null,
      threadLimit: null,
      image: ImageProcessingConfig.initial(),
    );
  }

  factory MediaTaskConfig.initialAudio() {
    return MediaTaskConfig(
      outputLocationMode: OutputLocationMode.system,
      outputDirectory: '',
      outputFileName: '',
      compressionMode: CompressionMode.preset,
      preset: MediaProcessingPreset.balanced,
      targetSizeBytes: null,
      targetSizeRatio: null,
      threadLimit: null,
      audio: AudioProcessingConfig.initial(),
    );
  }

  factory MediaTaskConfig.initialDefaults() {
    return MediaTaskConfig(
      outputLocationMode: OutputLocationMode.system,
      outputDirectory: '',
      outputFileName: '',
      compressionMode: CompressionMode.preset,
      preset: MediaProcessingPreset.balanced,
      targetSizeBytes: null,
      targetSizeRatio: null,
      threadLimit: null,
      video: VideoProcessingConfig.initial(),
      image: ImageProcessingConfig.initial(),
      audio: AudioProcessingConfig.initial(),
    );
  }

  factory MediaTaskConfig.fromVideoTaskConfig(VideoTaskConfig config) {
    return MediaTaskConfig(
      outputLocationMode: config.outputDirectory.trim().isEmpty
          ? OutputLocationMode.source
          : OutputLocationMode.custom,
      outputDirectory: config.outputDirectory,
      outputFileName: config.outputFileName,
      compressionMode: config.compressionMode,
      preset: _mediaPresetFromSmartPreset(config.smartPreset),
      targetSizeBytes: config.targetSizeBytes,
      targetSizeRatio: config.targetSizeRatio,
      threadLimit: null,
      video: VideoProcessingConfig(
        outputFormat: MediaOutputFormat.fromVideoOutputFormat(
          config.outputFormat,
        ),
        keepOriginalOutputFormat: false,
        videoCodec: config.videoCodec,
        encoderBackend: config.encoderBackend,
        hdrOutputMode: HdrOutputMode.convertToSdr,
        resolutionPreset: config.resolutionPreset,
        compressionCrf: config.compressionCrf,
        smartPreset: config.smartPreset,
        preserveMetadata: true,
      ),
    );
  }

  static MediaTaskConfig normalize(Object? config, MediaKind mediaKind) {
    if (config is MediaTaskConfig) {
      return config;
    }
    if (config is VideoTaskConfig) {
      return MediaTaskConfig.fromVideoTaskConfig(config);
    }
    if (config == null) {
      return MediaTaskConfig.initialFor(mediaKind);
    }

    throw ArgumentError.value(config, 'config', '不支持的媒体任务配置类型');
  }

  bool isValidFor(MediaKind mediaKind) {
    return switch (mediaKind) {
      MediaKind.video => video != null,
      MediaKind.image => image != null,
      MediaKind.audio => audio != null,
    };
  }

  MediaTaskConfig forKind(MediaKind mediaKind) {
    return MediaTaskConfig(
      outputLocationMode: outputLocationMode,
      outputDirectory: outputDirectory,
      outputFileName: outputFileName,
      compressionMode: compressionMode,
      preset: preset,
      targetSizeBytes: targetSizeBytes,
      targetSizeRatio: targetSizeRatio,
      threadLimit: threadLimit,
      video: mediaKind == MediaKind.video
          ? video ?? VideoProcessingConfig.initial()
          : null,
      image: mediaKind == MediaKind.image
          ? image ?? ImageProcessingConfig.initial()
          : null,
      audio: mediaKind == MediaKind.audio
          ? audio ?? AudioProcessingConfig.initial()
          : null,
    );
  }

  MediaTaskConfig copyWith({
    OutputLocationMode? outputLocationMode,
    String? outputDirectory,
    String? outputFileName,
    CompressionMode? compressionMode,
    Object? preset = _notProvided,
    Object? targetSizeBytes = _notProvided,
    Object? targetSizeRatio = _notProvided,
    Object? threadLimit = _notProvided,
    VideoProcessingConfig? video,
    ImageProcessingConfig? image,
    AudioProcessingConfig? audio,
    OutputFormat? outputFormat,
    bool? keepOriginalOutputFormat,
    VideoCodec? videoCodec,
    EncoderBackend? encoderBackend,
    HdrOutputMode? hdrOutputMode,
    Object? videoCodecBeforePreserveHdr = _notProvided,
    Object? encoderBackendBeforePreserveHdr = _notProvided,
    ResolutionPreset? resolutionPreset,
    int? compressionCrf,
    Object? smartPreset = _notProvided,
  }) {
    final currentVideo = this.video;
    final nextSmartPreset = identical(smartPreset, _notProvided)
        ? currentVideo?.smartPreset
        : smartPreset as SmartCompressionPreset?;
    final nextOutputFormat = mediaOutputFormatFromVideoOutput(outputFormat);
    final nextVideo =
        video ??
        currentVideo?.copyWith(
          outputFormat: nextOutputFormat,
          keepOriginalOutputFormat: keepOriginalOutputFormat,
          videoCodec: videoCodec,
          encoderBackend: encoderBackend,
          hdrOutputMode: hdrOutputMode,
          videoCodecBeforePreserveHdr: videoCodecBeforePreserveHdr,
          encoderBackendBeforePreserveHdr: encoderBackendBeforePreserveHdr,
          resolutionPreset: resolutionPreset,
          compressionCrf: compressionCrf,
          smartPreset: nextSmartPreset,
        );

    return MediaTaskConfig(
      outputLocationMode: outputLocationMode ?? this.outputLocationMode,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      outputFileName: outputFileName ?? this.outputFileName,
      compressionMode: compressionMode ?? this.compressionMode,
      preset: identical(preset, _notProvided)
          ? this.preset
          : preset as MediaProcessingPreset?,
      targetSizeBytes: identical(targetSizeBytes, _notProvided)
          ? this.targetSizeBytes
          : targetSizeBytes as int?,
      targetSizeRatio: identical(targetSizeRatio, _notProvided)
          ? this.targetSizeRatio
          : targetSizeRatio as double?,
      threadLimit: identical(threadLimit, _notProvided)
          ? this.threadLimit
          : normalizeThreadLimit(threadLimit as int?),
      video: nextVideo,
      image: image ?? this.image,
      audio: audio ?? this.audio,
    );
  }

  OutputFormat get outputFormat =>
      _requireVideo.outputFormat.toVideoOutputFormat();

  VideoCodec get videoCodec => _requireVideo.videoCodec;

  EncoderBackend get encoderBackend => _requireVideo.encoderBackend;

  ResolutionPreset get resolutionPreset => _requireVideo.resolutionPreset;

  int get compressionCrf => _requireVideo.compressionCrf;

  SmartCompressionPreset? get smartPreset => _requireVideo.smartPreset;

  VideoProcessingConfig get _requireVideo {
    final value = video;
    if (value == null) {
      throw StateError('当前媒体任务没有视频配置');
    }
    return value;
  }

  static MediaProcessingPreset? _mediaPresetFromSmartPreset(
    SmartCompressionPreset? preset,
  ) {
    return switch (preset) {
      SmartCompressionPreset.clear => MediaProcessingPreset.sourceLike,
      SmartCompressionPreset.balanced => MediaProcessingPreset.balanced,
      SmartCompressionPreset.chat => MediaProcessingPreset.smaller,
      SmartCompressionPreset.compact => MediaProcessingPreset.smallest,
      null => null,
    };
  }
}

int? normalizeThreadLimit(int? value) {
  if (value == null) {
    return null;
  }
  return value.clamp(minThreadCount, maxThreadCount);
}

MediaOutputFormat? mediaOutputFormatFromVideoOutput(OutputFormat? format) {
  if (format == null) {
    return null;
  }

  return MediaOutputFormat.fromVideoOutputFormat(format);
}
