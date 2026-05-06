import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/domain/value_objects/app_compression_settings.dart';

/// 应用全局设置
class AppSettings {
  /// 默认输出路径
  final String? defaultOutputDirectory;

  /// 用户最后选择的输出目录
  final String? lastSelectedOutputDirectory;

  /// 自定义Ffmpeg编码器的路径
  final String? customFfmpegPath;

  /// 自定义Ffprobe分析器的路径
  final String? customFfprobePath;

  /// 是否显示原始日志(如果不显示就是友好日志)
  final bool showRawLog;

  /// 开启高级选项
  final bool showAdvancedOptions;

  /// 应用级压缩默认设置
  final AppCompressionSettings compressionSettings;

  AppSettings({
    this.defaultOutputDirectory,
    this.lastSelectedOutputDirectory,
    this.customFfmpegPath,
    this.customFfprobePath,
    required this.showRawLog,
    required this.showAdvancedOptions,
    AppCompressionSettings? compressionSettings,
    VideoCodec? defaultOutputVideoCodec,
  }) : compressionSettings =
           compressionSettings ??
           AppCompressionSettings(
             defaultOutputVideoCodec:
                 defaultOutputVideoCodec ??
                 AppCompressionSettings.initial().defaultOutputVideoCodec,
           );

  /// 默认设置
  factory AppSettings.initial() {
    return AppSettings(
      defaultOutputDirectory: null,
      lastSelectedOutputDirectory: null,
      customFfmpegPath: null,
      customFfprobePath: null,
      showRawLog: false,
      showAdvancedOptions: false,
      compressionSettings: AppCompressionSettings.initial(),
    );
  }

  AppSettings copyWith({
    String? defaultOutputDirectory,
    String? lastSelectedOutputDirectory,
    String? customFfmpegPath,
    String? customFfprobePath,
    bool? preferRawLogView,
    bool? showAdvancedOptions,
    AppCompressionSettings? compressionSettings,
    VideoCodec? defaultOutputVideoCodec,
  }) {
    return AppSettings(
      defaultOutputDirectory:
          defaultOutputDirectory ?? this.defaultOutputDirectory,
      lastSelectedOutputDirectory:
          lastSelectedOutputDirectory ?? this.lastSelectedOutputDirectory,
      customFfmpegPath: customFfmpegPath ?? this.customFfmpegPath,
      customFfprobePath: customFfprobePath ?? this.customFfprobePath,
      showRawLog: preferRawLogView ?? showRawLog,
      showAdvancedOptions: showAdvancedOptions ?? this.showAdvancedOptions,
      compressionSettings:
          compressionSettings ??
          this.compressionSettings.copyWith(
            defaultOutputVideoCodec: defaultOutputVideoCodec,
          ),
    );
  }

  VideoCodec get defaultOutputVideoCodec =>
      compressionSettings.defaultOutputVideoCodec;

  /// 替换自定义 FFmpeg 编码器路径
  AppSettings withCustomFfmpegPath(String? path) {
    return AppSettings(
      defaultOutputDirectory: defaultOutputDirectory,
      lastSelectedOutputDirectory: lastSelectedOutputDirectory,
      customFfmpegPath: path,
      customFfprobePath: customFfprobePath,
      showRawLog: showRawLog,
      showAdvancedOptions: showAdvancedOptions,
      compressionSettings: compressionSettings,
    );
  }

  /// 替换自定义 FFprobe 分析器路径
  AppSettings withCustomFfprobePath(String? path) {
    return AppSettings(
      defaultOutputDirectory: defaultOutputDirectory,
      lastSelectedOutputDirectory: lastSelectedOutputDirectory,
      customFfmpegPath: customFfmpegPath,
      customFfprobePath: path,
      showRawLog: showRawLog,
      showAdvancedOptions: showAdvancedOptions,
      compressionSettings: compressionSettings,
    );
  }
}
