import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';

const Object _notProvided = Object();

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

  /// 压缩控制方式
  final CompressionMode compressionMode;

  /// 推荐方案；只在推荐预设模式下使用
  final SmartCompressionPreset? smartPreset;

  /// 目标体积字节数；只在指定目标体积模式下使用
  final int? targetSizeBytes;

  /// 目标体积占源文件体积的比例；旧版本兼容字段，不再作为核心目标
  final double? targetSizeRatio;

  /// 用户自定义输出文件名；为空时由系统自动生成
  final String outputFileName;

  VideoTaskConfig({
    required this.outputFormat,
    required this.videoCodec,
    required this.encoderBackend,
    required this.resolutionPreset,
    required this.outputDirectory,
    required this.compressionCrf,
    required this.compressionMode,
    required this.smartPreset,
    required this.targetSizeBytes,
    required this.targetSizeRatio,
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
      compressionMode: CompressionMode.preset,
      smartPreset: SmartCompressionPreset.balanced,
      targetSizeBytes: null,
      targetSizeRatio: null,
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
    CompressionMode? compressionMode,
    Object? smartPreset = _notProvided,
    Object? targetSizeBytes = _notProvided,
    Object? targetSizeRatio = _notProvided,
    String? outputFileName,
  }) {
    return VideoTaskConfig(
      outputFormat: outputFormat ?? this.outputFormat,
      videoCodec: videoCodec ?? this.videoCodec,
      encoderBackend: encoderBackend ?? this.encoderBackend,
      resolutionPreset: resolutionPreset ?? this.resolutionPreset,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      compressionCrf: compressionCrf ?? this.compressionCrf,
      compressionMode: compressionMode ?? this.compressionMode,
      smartPreset: identical(smartPreset, _notProvided)
          ? this.smartPreset
          : smartPreset as SmartCompressionPreset?,
      targetSizeBytes: identical(targetSizeBytes, _notProvided)
          ? this.targetSizeBytes
          : targetSizeBytes as int?,
      targetSizeRatio: identical(targetSizeRatio, _notProvided)
          ? this.targetSizeRatio
          : targetSizeRatio as double?,
      outputFileName: outputFileName ?? this.outputFileName,
    );
  }
}
