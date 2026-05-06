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

  bool get canEncode => ffmpeg != null;
  bool get canAnalyze => ffprobe != null;

  const ResolvedFfmpegRuntime({required this.ffmpeg, required this.ffprobe});
}

/// 用户主动设置的工具路径无效
class InvalidFfmpegToolPathException implements Exception {
  final String toolName;
  final String inputPath;

  InvalidFfmpegToolPathException({
    required this.toolName,
    required this.inputPath,
  });

  @override
  String toString() {
    return '$toolName 路径不可用: $inputPath';
  }
}

/// FFmpeg 路径查找服务抽象
abstract class FfmpegLocator {
  /// 启动时解析运行时状态，旧的自定义路径不可用时会自动降级
  Future<ResolvedFfmpegRuntime> resolve({
    String? customFfmpegPath,
    String? customFfprobePath,
  });

  /// 用户主动设置 ffmpeg 路径时使用，路径不可用必须抛异常
  Future<ResolvedFfmpegTool> validateCustomFfmpegPath(String inputPath);

  /// 用户主动设置 ffprobe 路径时使用，路径不可用必须抛异常
  Future<ResolvedFfmpegTool> validateCustomFfprobePath(String inputPath);
}
