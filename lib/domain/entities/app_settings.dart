import 'package:framelean/domain/enums/default_output_file_name_template.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/app_compression_settings.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';

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

  /// 应用级通用媒体处理默认配置
  final MediaTaskConfig defaultMediaConfig;

  /// 应用级默认导出文件名模板
  final DefaultOutputFileNameTemplate defaultOutputFileNameTemplate;

  /// 应用主题模式
  final AppThemeMode themeMode;

  /// 是否关闭工作台通知未读角标
  final bool hideNotificationBadge;

  AppSettings({
    this.defaultOutputDirectory,
    this.lastSelectedOutputDirectory,
    this.saveOutputToSourceDirectory = true,
    this.customFfmpegPath,
    this.customFfprobePath,
    required this.showRawLog,
    required this.showAdvancedOptions,
    AppCompressionSettings? compressionSettings,
    MediaTaskConfig? defaultMediaConfig,
    VideoCodec? defaultOutputVideoCodec,
    SmartCompressionPreset? defaultSmartPreset,
    this.defaultOutputFileNameTemplate =
        DefaultOutputFileNameTemplate.sourceFileNameCodec,
    this.themeMode = AppThemeMode.system,
    this.hideNotificationBadge = true,
  }) : defaultMediaConfig = resolveAppDefaultMediaConfig(
         defaultMediaConfig: defaultMediaConfig,
         compressionSettings: compressionSettings,
         defaultOutputVideoCodec: defaultOutputVideoCodec,
         defaultSmartPreset: defaultSmartPreset,
       ),
       compressionSettings = compressionSettingsFromDefaultMediaConfig(
         resolveAppDefaultMediaConfig(
           defaultMediaConfig: defaultMediaConfig,
           compressionSettings: compressionSettings,
           defaultOutputVideoCodec: defaultOutputVideoCodec,
           defaultSmartPreset: defaultSmartPreset,
         ),
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
      defaultMediaConfig: MediaTaskConfig.initialDefaults(),
      defaultOutputFileNameTemplate:
          DefaultOutputFileNameTemplate.sourceFileNameCodec,
      themeMode: AppThemeMode.system,
      hideNotificationBadge: true,
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
    MediaTaskConfig? defaultMediaConfig,
    VideoCodec? defaultOutputVideoCodec,
    SmartCompressionPreset? defaultSmartPreset,
    DefaultOutputFileNameTemplate? defaultOutputFileNameTemplate,
    AppThemeMode? themeMode,
    bool? hideNotificationBadge,
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
      compressionSettings: compressionSettings,
      defaultMediaConfig: defaultMediaConfig ?? this.defaultMediaConfig,
      defaultOutputVideoCodec: defaultOutputVideoCodec,
      defaultSmartPreset: defaultSmartPreset,
      defaultOutputFileNameTemplate:
          defaultOutputFileNameTemplate ?? this.defaultOutputFileNameTemplate,
      themeMode: themeMode ?? this.themeMode,
      hideNotificationBadge:
          hideNotificationBadge ?? this.hideNotificationBadge,
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

MediaTaskConfig resolveAppDefaultMediaConfig({
  MediaTaskConfig? defaultMediaConfig,
  AppCompressionSettings? compressionSettings,
  VideoCodec? defaultOutputVideoCodec,
  SmartCompressionPreset? defaultSmartPreset,
}) {
  final fallback = MediaTaskConfig.initialDefaults();
  final base = defaultMediaConfig ?? fallback;
  final videoCodecOverride =
      defaultOutputVideoCodec ?? compressionSettings?.defaultOutputVideoCodec;
  final smartPresetOverride =
      defaultSmartPreset ?? compressionSettings?.defaultSmartPreset;
  final baseVideo = base.video ?? fallback.video!;
  final videoWithCodec = baseVideo.copyWith(videoCodec: videoCodecOverride);
  final resolvedVideo = smartPresetOverride == null
      ? videoWithCodec
      : videoWithCodec.copyWith(smartPreset: smartPresetOverride);

  return MediaTaskConfig(
    outputDirectory: base.outputDirectory,
    outputFileName: base.outputFileName,
    compressionMode: base.compressionMode,
    preset: base.preset,
    targetSizeBytes: base.targetSizeBytes,
    targetSizeRatio: base.targetSizeRatio,
    video: resolvedVideo,
    image: base.image ?? fallback.image,
    audio: base.audio ?? fallback.audio,
  );
}

AppCompressionSettings compressionSettingsFromDefaultMediaConfig(
  MediaTaskConfig config,
) {
  final video = config.video ?? MediaTaskConfig.initialDefaults().video!;
  return AppCompressionSettings(
    defaultOutputVideoCodec: video.videoCodec,
    defaultSmartPreset: video.smartPreset ?? SmartCompressionPreset.balanced,
  );
}
