import 'package:machining/domain/enums/default_output_file_name_template.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/domain/value_objects/app_compression_settings.dart';

const Object _notProvided = Object();

/// 应用全局设置
class AppSettings {
  /// 默认输出路径
  final String? defaultOutputDirectory;

  /// 用户最后选择的输出目录
  final String? lastSelectedOutputDirectory;

  /// 默认导出时是否保存到源文件旁
  final bool saveOutputToSourceDirectory;

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

  /// 应用级默认导出文件名模板
  final DefaultOutputFileNameTemplate defaultOutputFileNameTemplate;

  AppSettings({
    this.defaultOutputDirectory,
    this.lastSelectedOutputDirectory,
    this.saveOutputToSourceDirectory = true,
    this.customFfmpegPath,
    this.customFfprobePath,
    required this.showRawLog,
    required this.showAdvancedOptions,
    AppCompressionSettings? compressionSettings,
    VideoCodec? defaultOutputVideoCodec,
    SmartCompressionPreset? defaultSmartPreset,
    this.defaultOutputFileNameTemplate =
        DefaultOutputFileNameTemplate.datetimeOriginalCodec,
  }) : compressionSettings =
           compressionSettings ??
           AppCompressionSettings(
             defaultOutputVideoCodec:
                 defaultOutputVideoCodec ??
                 AppCompressionSettings.initial().defaultOutputVideoCodec,
             defaultSmartPreset:
                 defaultSmartPreset ??
                 AppCompressionSettings.initial().defaultSmartPreset,
           );

  /// 默认设置
  factory AppSettings.initial() {
    return AppSettings(
      defaultOutputDirectory: null,
      lastSelectedOutputDirectory: null,
      saveOutputToSourceDirectory: true,
      customFfmpegPath: null,
      customFfprobePath: null,
      showRawLog: false,
      showAdvancedOptions: false,
      compressionSettings: AppCompressionSettings.initial(),
      defaultOutputFileNameTemplate:
          DefaultOutputFileNameTemplate.datetimeOriginalCodec,
    );
  }

  AppSettings copyWith({
    Object? defaultOutputDirectory = _notProvided,
    Object? lastSelectedOutputDirectory = _notProvided,
    bool? saveOutputToSourceDirectory,
    Object? customFfmpegPath = _notProvided,
    Object? customFfprobePath = _notProvided,
    bool? preferRawLogView,
    bool? showAdvancedOptions,
    AppCompressionSettings? compressionSettings,
    VideoCodec? defaultOutputVideoCodec,
    SmartCompressionPreset? defaultSmartPreset,
    DefaultOutputFileNameTemplate? defaultOutputFileNameTemplate,
  }) {
    return AppSettings(
      defaultOutputDirectory: identical(defaultOutputDirectory, _notProvided)
          ? this.defaultOutputDirectory
          : defaultOutputDirectory as String?,
      lastSelectedOutputDirectory:
          identical(lastSelectedOutputDirectory, _notProvided)
          ? this.lastSelectedOutputDirectory
          : lastSelectedOutputDirectory as String?,
      saveOutputToSourceDirectory:
          saveOutputToSourceDirectory ?? this.saveOutputToSourceDirectory,
      customFfmpegPath: identical(customFfmpegPath, _notProvided)
          ? this.customFfmpegPath
          : customFfmpegPath as String?,
      customFfprobePath: identical(customFfprobePath, _notProvided)
          ? this.customFfprobePath
          : customFfprobePath as String?,
      showRawLog: preferRawLogView ?? showRawLog,
      showAdvancedOptions: showAdvancedOptions ?? this.showAdvancedOptions,
      compressionSettings:
          compressionSettings ??
          this.compressionSettings.copyWith(
            defaultOutputVideoCodec: defaultOutputVideoCodec,
            defaultSmartPreset: defaultSmartPreset,
          ),
      defaultOutputFileNameTemplate:
          defaultOutputFileNameTemplate ?? this.defaultOutputFileNameTemplate,
    );
  }

  VideoCodec get defaultOutputVideoCodec =>
      compressionSettings.defaultOutputVideoCodec;

  SmartCompressionPreset get defaultSmartPreset =>
      compressionSettings.defaultSmartPreset;

  /// 替换自定义 FFmpeg 编码器路径
  AppSettings withCustomFfmpegPath(String? path) {
    return copyWith(customFfmpegPath: path);
  }

  /// 替换自定义 FFprobe 分析器路径
  AppSettings withCustomFfprobePath(String? path) {
    return copyWith(customFfprobePath: path);
  }
}
