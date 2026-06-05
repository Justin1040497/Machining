import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';

const Object _notProvided = Object();

/// 视频任务的分类型处理配置。
class VideoProcessingConfig {
  final MediaOutputFormat outputFormat;
  final VideoCodec videoCodec;
  final EncoderBackend encoderBackend;
  final ResolutionPreset resolutionPreset;
  final int compressionCrf;
  final SmartCompressionPreset? smartPreset;

  const VideoProcessingConfig({
    required this.outputFormat,
    required this.videoCodec,
    required this.encoderBackend,
    required this.resolutionPreset,
    required this.compressionCrf,
    required this.smartPreset,
  });

  factory VideoProcessingConfig.initial() {
    return const VideoProcessingConfig(
      outputFormat: MediaOutputFormat.mp4,
      videoCodec: VideoCodec.h264,
      encoderBackend: EncoderBackend.auto,
      resolutionPreset: ResolutionPreset.original,
      compressionCrf: 28,
      smartPreset: SmartCompressionPreset.balanced,
    );
  }

  VideoProcessingConfig copyWith({
    MediaOutputFormat? outputFormat,
    VideoCodec? videoCodec,
    EncoderBackend? encoderBackend,
    ResolutionPreset? resolutionPreset,
    int? compressionCrf,
    Object? smartPreset = _notProvided,
  }) {
    return VideoProcessingConfig(
      outputFormat: outputFormat ?? this.outputFormat,
      videoCodec: videoCodec ?? this.videoCodec,
      encoderBackend: encoderBackend ?? this.encoderBackend,
      resolutionPreset: resolutionPreset ?? this.resolutionPreset,
      compressionCrf: compressionCrf ?? this.compressionCrf,
      smartPreset: identical(smartPreset, _notProvided)
          ? this.smartPreset
          : smartPreset as SmartCompressionPreset?,
    );
  }
}
