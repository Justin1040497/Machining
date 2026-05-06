import 'package:machining/domain/enums/encoder_backend.dart';
import 'package:machining/domain/enums/output_format.dart';
import 'package:machining/domain/enums/resolution_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';

/// 单个视频任务的配置输出
class VideoTaskConfig {
  /// 输出格式是什么
  final OutputFormat outputFormat;

  /// 视频编码格式是什么
  final VideoCodec videoCodec;

  /// 编码是用什么实现的
  final EncoderBackend encoderBackend;

  /// 分辨率预设是什么
  final ResolutionPreset resolutionPreset;

  /// 文件输出目录是什么
  final String outputDirectory;

  /// 普通压缩模式使用的 CRF 值
  final int compressionCrf;

  /// 用户自定义输出文件名；为空时由系统自动生成
  final String outputFileName;

  VideoTaskConfig({
    required this.outputFormat,
    required this.videoCodec,
    required this.encoderBackend,
    required this.resolutionPreset,
    required this.outputDirectory,
    required this.compressionCrf,
    required this.outputFileName,
  });

  /// 默认配置
  factory VideoTaskConfig.initial() {
    return VideoTaskConfig(
      outputFormat: OutputFormat.mp4,
      videoCodec: VideoCodec.h264,
      encoderBackend: EncoderBackend.auto,
      resolutionPreset: ResolutionPreset.original,
      outputDirectory: '',
      compressionCrf: 28,
      outputFileName: '',
    );
  }

  /// 复制旧对象 只替换想改的字段
  VideoTaskConfig copyWith({
    OutputFormat? outputFormat,
    VideoCodec? videoCodec,
    EncoderBackend? encoderBackend,
    ResolutionPreset? resolutionPreset,
    String? outputDirectory,
    int? compressionCrf,
    String? outputFileName,
  }) {
    return VideoTaskConfig(
      outputFormat: outputFormat ?? this.outputFormat,
      videoCodec: videoCodec ?? this.videoCodec,
      encoderBackend: encoderBackend ?? this.encoderBackend,
      resolutionPreset: resolutionPreset ?? this.resolutionPreset,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      compressionCrf: compressionCrf ?? this.compressionCrf,
      outputFileName: outputFileName ?? this.outputFileName,
    );
  }
}
