import 'package:machining/domain/enums/video_codec.dart';

/// 应用级压缩默认设置。
///
/// 这里保存的是用户没有为单个任务单独选择时使用的默认值。
class AppCompressionSettings {
  final VideoCodec defaultOutputVideoCodec;

  const AppCompressionSettings({required this.defaultOutputVideoCodec});

  factory AppCompressionSettings.initial() {
    return const AppCompressionSettings(
      defaultOutputVideoCodec: VideoCodec.h264,
    );
  }

  AppCompressionSettings copyWith({VideoCodec? defaultOutputVideoCodec}) {
    return AppCompressionSettings(
      defaultOutputVideoCodec:
          defaultOutputVideoCodec ?? this.defaultOutputVideoCodec,
    );
  }
}
