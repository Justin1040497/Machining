import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';

/// 应用级压缩默认设置。
///
/// 这里保存的是用户没有为单个任务单独选择时使用的默认值。
class AppCompressionSettings {
  final VideoCodec defaultOutputVideoCodec;
  final SmartCompressionPreset defaultSmartPreset;

  const AppCompressionSettings({
    required this.defaultOutputVideoCodec,
    required this.defaultSmartPreset,
  });

  factory AppCompressionSettings.initial() {
    return const AppCompressionSettings(
      defaultOutputVideoCodec: VideoCodec.h264,
      defaultSmartPreset: SmartCompressionPreset.balanced,
    );
  }

  AppCompressionSettings copyWith({
    VideoCodec? defaultOutputVideoCodec,
    SmartCompressionPreset? defaultSmartPreset,
  }) {
    return AppCompressionSettings(
      defaultOutputVideoCodec:
          defaultOutputVideoCodec ?? this.defaultOutputVideoCodec,
      defaultSmartPreset: defaultSmartPreset ?? this.defaultSmartPreset,
    );
  }
}
