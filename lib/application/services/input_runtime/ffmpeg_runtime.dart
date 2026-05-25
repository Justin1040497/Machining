import 'package:machining/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';

/// FFmpeg 二进制来源
enum FfmpegBinarySource {
  /// 用户自定义路径优先
  custom,

  /// 应用内置路径其次
  bundled,

  /// 系统 PATH 最后
  systemPath,
}

/// 已解析出的单个 FFmpeg 工具
class ResolvedFfmpegTool {
  final String path;
  final FfmpegBinarySource source;

  const ResolvedFfmpegTool({required this.path, required this.source});
}

/// 当前 FFmpeg / FFprobe 运行时状态
class ResolvedFfmpegRuntime {
  final ResolvedFfmpegTool? ffmpeg;
  final ResolvedFfmpegTool? ffprobe;
  final FfmpegEncoderCapabilities encoderCapabilities;

  bool get canEncode => ffmpeg != null;
  bool get canAnalyze => ffprobe != null;

  const ResolvedFfmpegRuntime({
    required this.ffmpeg,
    required this.ffprobe,
    this.encoderCapabilities = FfmpegEncoderCapabilities.softwareOnly,
  });
}
