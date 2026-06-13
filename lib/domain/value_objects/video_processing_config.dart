import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/hdr_output_mode.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';

const Object _notProvided = Object();

/// 视频任务的分类型处理配置。
class VideoProcessingConfig {
  final MediaOutputFormat outputFormat;
  final bool keepOriginalOutputFormat;
  final VideoCodec videoCodec;
  final EncoderBackend encoderBackend;
  final HdrOutputMode hdrOutputMode;
  final VideoCodec? videoCodecBeforePreserveHdr;
  final EncoderBackend? encoderBackendBeforePreserveHdr;
  final ResolutionPreset resolutionPreset;
  final int compressionCrf;
  final SmartCompressionPreset? smartPreset;
  final bool preserveMetadata;

  const VideoProcessingConfig({
    required this.outputFormat,
    required this.keepOriginalOutputFormat,
    required this.videoCodec,
    required this.encoderBackend,
    required this.hdrOutputMode,
    this.videoCodecBeforePreserveHdr,
    this.encoderBackendBeforePreserveHdr,
    required this.resolutionPreset,
    required this.compressionCrf,
    required this.smartPreset,
    required this.preserveMetadata,
  });

  factory VideoProcessingConfig.initial() {
    return const VideoProcessingConfig(
      outputFormat: MediaOutputFormat.mp4,
      keepOriginalOutputFormat: false,
      videoCodec: VideoCodec.h264,
      encoderBackend: EncoderBackend.auto,
      hdrOutputMode: HdrOutputMode.convertToSdr,
      resolutionPreset: ResolutionPreset.original,
      compressionCrf: 28,
      smartPreset: SmartCompressionPreset.balanced,
      preserveMetadata: true,
    );
  }

  VideoProcessingConfig copyWith({
    MediaOutputFormat? outputFormat,
    bool? keepOriginalOutputFormat,
    VideoCodec? videoCodec,
    EncoderBackend? encoderBackend,
    HdrOutputMode? hdrOutputMode,
    Object? videoCodecBeforePreserveHdr = _notProvided,
    Object? encoderBackendBeforePreserveHdr = _notProvided,
    ResolutionPreset? resolutionPreset,
    int? compressionCrf,
    Object? smartPreset = _notProvided,
    bool? preserveMetadata,
  }) {
    return VideoProcessingConfig(
      outputFormat: outputFormat ?? this.outputFormat,
      keepOriginalOutputFormat:
          keepOriginalOutputFormat ?? this.keepOriginalOutputFormat,
      videoCodec: videoCodec ?? this.videoCodec,
      encoderBackend: encoderBackend ?? this.encoderBackend,
      hdrOutputMode: hdrOutputMode ?? this.hdrOutputMode,
      videoCodecBeforePreserveHdr:
          identical(videoCodecBeforePreserveHdr, _notProvided)
          ? this.videoCodecBeforePreserveHdr
          : videoCodecBeforePreserveHdr as VideoCodec?,
      encoderBackendBeforePreserveHdr:
          identical(encoderBackendBeforePreserveHdr, _notProvided)
          ? this.encoderBackendBeforePreserveHdr
          : encoderBackendBeforePreserveHdr as EncoderBackend?,
      resolutionPreset: resolutionPreset ?? this.resolutionPreset,
      compressionCrf: compressionCrf ?? this.compressionCrf,
      smartPreset: identical(smartPreset, _notProvided)
          ? this.smartPreset
          : smartPreset as SmartCompressionPreset?,
      preserveMetadata: preserveMetadata ?? this.preserveMetadata,
    );
  }
}
