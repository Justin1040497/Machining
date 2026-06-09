import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:framelean/app/theme/app_theme_controller.dart';
import 'package:framelean/application/services/app_maintenance/app_cache_cleaner.dart';
import 'package:framelean/application/services/app_maintenance/app_uninstaller.dart';
import 'package:framelean/application/services/framelean_build_info.dart';
import 'package:framelean/application/use_cases/app_maintenance/clear_app_cache_use_case.dart';
import 'package:framelean/application/use_cases/app_maintenance/launch_clean_uninstaller_use_case.dart';
import 'package:framelean/application/use_cases/app_maintenance/load_app_uninstall_availability_use_case.dart';
import 'package:framelean/application/use_cases/app_maintenance/preview_app_cache_cleanup_use_case.dart';
import 'package:framelean/application/use_cases/app_settings/load_app_settings_use_case.dart';
import 'package:framelean/application/use_cases/app_settings/save_app_settings_use_case.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/default_output_file_name_template.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/video_processing_config.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_external_link_opener.dart';
import 'package:framelean/features/workbench/presentation_mappers/domain_labels.dart';
import 'package:framelean/features/workbench/theme/workbench_theme_context.dart';
import 'package:framelean/features/workbench/widgets/form_controls/config_dropdown.dart';
import 'package:framelean/features/workbench/widgets/form_controls/path_field.dart';
import 'package:framelean/features/workbench/providers/media_task_notifier.dart';
import 'package:framelean/infrastructure/providers/app_maintenance_provider.dart';
import 'package:framelean/infrastructure/providers/input_runtime_provider.dart';
import 'package:framelean/infrastructure/providers/repository_provider.dart';
import 'package:framelean/infrastructure/services/theme_prefs_cache.dart';
import 'package:path/path.dart' as path;

typedef AppSettingsSaveCallback = Future<void> Function(AppSettings settings);
typedef AppSettingsPathPicker = Future<String?> Function();
typedef AppCacheCleanupPreviewCallback =
    Future<AppCacheCleanupPreview> Function();
typedef AppCacheCleanupCallback = Future<AppCacheCleanupResult> Function();
typedef AppUninstallAvailabilityCallback =
    Future<AppUninstallAvailability> Function();
typedef AppUninstallLaunchCallback = Future<void> Function();
typedef AppSettingsExternalLinkCallback = Future<void> Function(String url);

const String _frameLeanGiteeUrl = 'https://gitee.com/zhouycheng/FrameLean';
const String _frameLeanGitHubUrl = 'https://github.com/zhouycheng/FrameLean';
const String _frameLeanGmailUrl = 'mailto:justinzhouself@gmail.com';
const String _frameLeanJuejinUrl = 'https://juejin.cn/user/394062317754227';

class AppSettingsPage extends ConsumerStatefulWidget {
  const AppSettingsPage({super.key});

  @override
  ConsumerState<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends ConsumerState<AppSettingsPage> {
  late Future<AppSettings> settingsFuture;

  @override
  void initState() {
    super.initState();
    settingsFuture = loadSettings();
  }

  Future<AppSettings> loadSettings() {
    return LoadAppSettingsUseCase(
      repository: ref.read(appSettingsRepositoryProvider),
    ).call();
  }

  void retryLoadSettings() {
    setState(() {
      settingsFuture = loadSettings();
    });
  }

  void returnToWorkbench({bool saved = false}) {
    if (context.canPop()) {
      context.pop(saved);
      return;
    }

    context.go('/');
  }

  Future<void> saveSettings(AppSettings settings) async {
    try {
      await SaveAppSettingsUseCase(
        repository: ref.read(appSettingsRepositoryProvider),
        ffmpegLocator: ref.read(ffmpegLocatorProvider),
      ).call(settings);
      ref.read(appThemeModeProvider.notifier).setThemeMode(settings.themeMode);
      unawaited(ThemePrefsCache.write(settings.themeMode));
      ref.invalidate(ffmpegRuntimeProvider);
      await ref
          .read(mediaTaskListProvider.notifier)
          .applySettingsToExistingTasks(settings);
      if (!mounted) {
        return;
      }

      returnToWorkbench(saved: true);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> launchCleanUninstaller() async {
    await LaunchCleanUninstallerUseCase(
      uninstaller: ref.read(appUninstallerProvider),
    ).call(currentProcessId: pid);
    exit(0);
  }

  Future<void> openExternalLink(String url) async {
    final result = await WorkbenchExternalLinkOpener.open(url);
    if (!mounted || result.succeeded) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message!)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Scaffold(
      backgroundColor: colors.surface,
      body: FutureBuilder<AppSettings>(
        future: settingsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return AppSettingsView(
              initialSettings: snapshot.requireData,
              fallbackDefaultDirectory: _SettingsFilePicker.defaultExportPath,
              onPickOutputDirectory: _SettingsFilePicker.pickOutputDirectory,
              onPickFfmpegPath: _SettingsFilePicker.pickExecutablePath,
              onPickFfprobePath: _SettingsFilePicker.pickExecutablePath,
              onPreviewAppCacheCleanup: () {
                return PreviewAppCacheCleanupUseCase(
                  cacheCleaner: ref.read(appCacheCleanerProvider),
                ).call();
              },
              onClearAppCache: () {
                return ClearAppCacheUseCase(
                  cacheCleaner: ref.read(appCacheCleanerProvider),
                ).call();
              },
              onLoadAppUninstallAvailability: () {
                return LoadAppUninstallAvailabilityUseCase(
                  uninstaller: ref.read(appUninstallerProvider),
                ).call();
              },
              onLaunchCleanUninstaller: launchCleanUninstaller,
              onOpenExternalLink: openExternalLink,
              onSave: saveSettings,
            );
          }

          if (snapshot.hasError) {
            return _SettingsLoadError(
              error: snapshot.error.toString(),
              onRetry: retryLoadSettings,
              onBack: () => returnToWorkbench(),
            );
          }

          return const _SettingsLoading();
        },
      ),
    );
  }
}

class _SettingsLoading extends StatelessWidget {
  const _SettingsLoading();

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
      ),
    );
  }
}

class _SettingsLoadError extends StatelessWidget {
  const _SettingsLoadError({
    required this.error,
    required this.onRetry,
    required this.onBack,
  });

  final String error;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '设置加载失败',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                error,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  FilledButton(onPressed: onRetry, child: const Text('重试')),
                  const SizedBox(width: 12),
                  TextButton(onPressed: onBack, child: const Text('返回工作台')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

abstract final class _SettingsFilePicker {
  static Future<String?> pickOutputDirectory() {
    return getDirectoryPath(confirmButtonText: '选择导出文件夹');
  }

  static Future<String?> pickExecutablePath() async {
    final file = await openFile();
    return file?.path;
  }

  static String get defaultExportPath {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null || home.trim().isEmpty) {
      return Directory.current.path;
    }

    return path.join(home, 'Desktop');
  }
}

class AppSettingsView extends StatefulWidget {
  const AppSettingsView({
    super.key,
    required this.initialSettings,
    required this.fallbackDefaultDirectory,
    required this.onPickOutputDirectory,
    required this.onPickFfmpegPath,
    required this.onPickFfprobePath,
    required this.onSave,
    this.onPreviewAppCacheCleanup,
    this.onClearAppCache,
    this.onLoadAppUninstallAvailability,
    this.onLaunchCleanUninstaller,
    this.onOpenExternalLink,
  });

  final AppSettings initialSettings;
  final String fallbackDefaultDirectory;
  final AppSettingsPathPicker onPickOutputDirectory;
  final AppSettingsPathPicker onPickFfmpegPath;
  final AppSettingsPathPicker onPickFfprobePath;
  final AppSettingsSaveCallback onSave;
  final AppCacheCleanupPreviewCallback? onPreviewAppCacheCleanup;
  final AppCacheCleanupCallback? onClearAppCache;
  final AppUninstallAvailabilityCallback? onLoadAppUninstallAvailability;
  final AppUninstallLaunchCallback? onLaunchCleanUninstaller;
  final AppSettingsExternalLinkCallback? onOpenExternalLink;

  @override
  State<AppSettingsView> createState() => _AppSettingsViewState();
}

class _AppSettingsViewState extends State<AppSettingsView> {
  static const _sidebarWidth = 168.0;
  static const _fieldHeight = 34.0;

  late _SettingsSection selectedSection;
  late AppThemeMode themeMode;
  late _CompletionSoundOption completionSoundOption;
  late bool saveOutputToSourceDirectory;
  late DefaultOutputFileNameTemplate outputFileNameTemplate;
  late MediaTaskConfig defaultMediaConfig;

  late final TextEditingController outputDirectoryController;
  late final TextEditingController ffmpegPathController;
  late final TextEditingController ffprobePathController;
  late final TextEditingController imageQualityController;

  bool outputDirectoryDragging = false;
  bool ffmpegPathDragging = false;
  bool ffprobePathDragging = false;
  bool saving = false;
  bool clearingCache = false;
  bool uninstalling = false;

  VideoProcessingConfig get videoConfig =>
      defaultMediaConfig.video ?? VideoProcessingConfig.initial();

  ImageProcessingConfig get imageConfig =>
      defaultMediaConfig.image ?? ImageProcessingConfig.initial();

  AudioProcessingConfig get audioConfig =>
      defaultMediaConfig.audio ?? AudioProcessingConfig.initial();

  @override
  void initState() {
    super.initState();
    selectedSection = _SettingsSection.app;
    themeMode = widget.initialSettings.themeMode;
    completionSoundOption = _CompletionSoundOption.none;
    saveOutputToSourceDirectory =
        widget.initialSettings.saveOutputToSourceDirectory;
    outputFileNameTemplate =
        widget.initialSettings.defaultOutputFileNameTemplate;
    defaultMediaConfig = _withAllMediaDefaults(
      widget.initialSettings.defaultMediaConfig,
    );

    outputDirectoryController = TextEditingController(
      text:
          widget.initialSettings.defaultOutputDirectory ??
          widget.fallbackDefaultDirectory,
    );
    ffmpegPathController = TextEditingController(
      text: widget.initialSettings.customFfmpegPath ?? '',
    );
    ffprobePathController = TextEditingController(
      text: widget.initialSettings.customFfprobePath ?? '',
    );
    imageQualityController = TextEditingController(
      text: imageConfig.imageQuality.toString(),
    );
  }

  @override
  void dispose() {
    outputDirectoryController.dispose();
    ffmpegPathController.dispose();
    ffprobePathController.dispose();
    imageQualityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            SizedBox(
              width: _sidebarWidth,
              child: _SettingsSidebar(
                selectedSection: selectedSection,
                saving: saving,
                onClose: saveAndClose,
                onSectionSelected: (section) {
                  setState(() => selectedSection = section);
                },
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: colors.border),
            Expanded(child: _SettingsContent(child: buildSelectedSection())),
          ],
        ),
      ),
    );
  }

  Widget buildSelectedSection() {
    return switch (selectedSection) {
      _SettingsSection.app => buildAppSettingsSection(),
      _SettingsSection.about => buildAboutSection(),
      _SettingsSection.video => buildVideoSection(),
      _SettingsSection.image => buildImageSection(),
      _SettingsSection.audio => buildAudioSection(),
      _SettingsSection.output => buildOutputSection(),
      _SettingsSection.encoder => buildEncoderSection(),
    };
  }

  Widget buildAppSettingsSection() {
    return _SettingsForm(
      title: '应用设置',
      children: [
        _SettingsDropdown<AppThemeMode>(
          label: '应用主题颜色',
          value: themeMode,
          values: AppThemeMode.values,
          itemLabel: (value) => value.settingsLabel,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => themeMode = value);
          },
        ),
        const SizedBox(height: 22),
        _SettingsDropdown<_CompletionSoundOption>(
          label: '完成音频设置',
          value: completionSoundOption,
          values: _CompletionSoundOption.values,
          itemLabel: (value) => value.label,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => completionSoundOption = value);
          },
        ),
      ],
    );
  }

  Widget buildAboutSection() {
    final colors = context.frameLeanColors;
    final iconPath = Theme.of(context).brightness == Brightness.dark
        ? 'assets/app_icon/light.png'
        : 'assets/app_icon/dark.png';
    final showUninstall = Platform.isWindows;

    return _SettingsForm(
      title: '关于',
      maxWidth: 560,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.asset(
            iconPath,
            width: 62,
            height: 62,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 18),
        _AboutTextBlock(
          title: '项目简介',
          body:
              'FrameLean（帧轻）是一个本地桌面媒体压缩与格式处理工具。'
              '基于 Flutter Desktop、FFmpeg / FFprobe、Riverpod、Drift 和 SQLite 构建。'
              '它把常用的视频、图片、音频分析、压缩、格式输出配置和任务队列能力封装成图形界面，'
              '让用户不用手写 FFmpeg 命令也能处理本地媒体文件。',
        ),
        const SizedBox(height: 18),
        _AboutTextBlock(
          title: '作者想说的话',
          body:
              '非常感谢你下载并使用我的应用，作者我通过比赛接触了 Flutter 和移动端开发近 2 年，'
              '这是我的第一款独立开发的应用。在使用过程中如果遇到了什么问题或者什么功能让你感到不方便，'
              '可以通过下面的方式联系作者，作者非常需要你提出的宝贵建议。',
        ),
        const SizedBox(height: 12),
        Text(
          '当前版本：${FrameLeanBuildInfo.currentVersionLabel}',
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
        _AboutIconLinks(onOpenLink: widget.onOpenExternalLink ?? (_) async {}),
        const SizedBox(height: 34),
        Wrap(
          spacing: 22,
          runSpacing: 12,
          children: [
            _MaintenanceButton(
              label: clearingCache ? '正在清理' : '清空应用缓存',
              color: colors.statusRunning,
              foregroundColor: colors.onWarning,
              onPressed: clearingCache ? null : confirmClearAppCache,
            ),
            if (showUninstall)
              _MaintenanceButton(
                label: uninstalling ? '正在准备' : '卸载应用',
                color: colors.statusFailed,
                foregroundColor: colors.onDanger,
                onPressed: uninstalling ? null : confirmUninstallApp,
              ),
          ],
        ),
      ],
    );
  }

  Widget buildVideoSection() {
    final config = videoConfig;
    final smartPreset = config.smartPreset ?? SmartCompressionPreset.balanced;

    return _SettingsForm(
      title: '视频任务默认值配置',
      children: [
        _SettingsDropdown<CompressionMode>(
          label: '默认模式选择',
          value: CompressionMode.preset,
          values: const [CompressionMode.preset],
          itemLabel: (value) => '推荐方案选项',
          onChanged: (_) {},
        ),
        const SizedBox(height: 22),
        _SettingsDropdown<SmartCompressionPreset>(
          label: '默认推荐方案预设',
          value: smartPreset,
          values: SmartCompressionPreset.values,
          itemLabel: (value) => value.label,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            updateVideoConfig(config.copyWith(smartPreset: value));
          },
        ),
        const SizedBox(height: 22),
        _TwoColumnFields(
          children: [
            _SettingsDropdown<MediaOutputFormat>(
              label: '默认输出格式',
              value: config.outputFormat,
              values: MediaOutputFormat.formatsFor(MediaKind.video),
              itemLabel: (value) => value.label,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                updateVideoConfig(config.copyWith(outputFormat: value));
              },
            ),
            _SettingsDropdown<VideoCodec>(
              label: '默认编码格式',
              value: config.videoCodec,
              values: VideoCodec.values,
              itemLabel: (value) => value.label,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                updateVideoConfig(
                  config.copyWith(
                    videoCodec: value,
                    encoderBackend: EncoderBackend.auto,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 22),
        _SettingsDropdown<ResolutionPreset>(
          label: '默认视频分辨率',
          width: 285,
          value: config.resolutionPreset,
          values: ResolutionPreset.values,
          itemLabel: (value) => value.label,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            updateVideoConfig(config.copyWith(resolutionPreset: value));
          },
        ),
      ],
    );
  }

  Widget buildImageSection() {
    final config = imageConfig;

    return _SettingsForm(
      title: '图片任务默认值配置',
      children: [
        _TwoColumnFields(
          children: [
            _SettingsDropdown<MediaOutputFormat>(
              label: '默认输出格式',
              value: config.outputFormat,
              values: MediaOutputFormat.formatsFor(MediaKind.image),
              itemLabel: (value) => value.label,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                updateImageConfig(config.copyWith(outputFormat: value));
              },
            ),
            _SettingsTextField(
              label: '默认图片质量',
              controller: imageQualityController,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed == null || parsed < 1 || parsed > 100) {
                  return;
                }
                updateImageConfig(config.copyWith(imageQuality: parsed));
              },
            ),
          ],
        ),
        const SizedBox(height: 22),
        _SettingsDropdown<ImageResizePreset>(
          label: '默认图片尺寸',
          width: 285,
          value: config.resizePreset,
          values: ImageResizePreset.values,
          itemLabel: (value) => value.label,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            updateImageConfig(config.copyWith(resizePreset: value));
          },
        ),
        const SizedBox(height: 16),
        _SettingsCheckbox(
          label: '保留图片元数据',
          value: config.preserveMetadata,
          onChanged: (value) {
            updateImageConfig(config.copyWith(preserveMetadata: value));
          },
        ),
      ],
    );
  }

  Widget buildAudioSection() {
    final config = audioConfig;

    return _SettingsForm(
      title: '音频任务默认值配置',
      children: [
        _TwoColumnFields(
          children: [
            _SettingsDropdown<MediaOutputFormat>(
              label: '默认输出格式',
              value: config.outputFormat,
              values: MediaOutputFormat.formatsFor(MediaKind.audio),
              itemLabel: (value) => value.label,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                updateAudioConfig(config.copyWith(outputFormat: value));
              },
            ),
            _SettingsDropdown<AudioBitratePreset>(
              label: '默认码率',
              value: config.bitratePreset,
              values: AudioBitratePreset.values,
              itemLabel: (value) => value.label,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                updateAudioConfig(config.copyWith(bitratePreset: value));
              },
            ),
          ],
        ),
        const SizedBox(height: 22),
        _TwoColumnFields(
          children: [
            _SettingsDropdown<AudioSampleRatePreset>(
              label: '默认采样率',
              value: config.sampleRate,
              values: AudioSampleRatePreset.values,
              itemLabel: (value) => value.label,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                updateAudioConfig(config.copyWith(sampleRate: value));
              },
            ),
            _SettingsDropdown<AudioChannelsPreset>(
              label: '默认声道',
              value: config.channels,
              values: AudioChannelsPreset.values,
              itemLabel: (value) => value.label,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                updateAudioConfig(config.copyWith(channels: value));
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget buildOutputSection() {
    return _SettingsForm(
      title: '输出配置',
      children: [
        _FormFieldLabel('默认导出地址'),
        const SizedBox(height: 8),
        _SettingsCheckbox(
          label: '保存到原文件旁',
          value: saveOutputToSourceDirectory,
          onChanged: (value) {
            setState(() => saveOutputToSourceDirectory = value);
          },
        ),
        const SizedBox(height: 8),
        _SettingsPathField(
          controller: outputDirectoryController,
          enabled: !saveOutputToSourceDirectory,
          highlighted: outputDirectoryDragging,
          hintText: widget.fallbackDefaultDirectory,
          trailingTooltip: '选择文件夹',
          onTrailingTap: pickOutputDirectory,
          onDraggingChanged: (value) {
            setState(() => outputDirectoryDragging = value);
          },
          onDropped: handleOutputDirectoryDrop,
        ),
        const SizedBox(height: 22),
        _SettingsDropdown<DefaultOutputFileNameTemplate>(
          label: '默认导出文件名',
          width: 360,
          value: outputFileNameTemplate,
          values: DefaultOutputFileNameTemplate.values,
          itemLabel: (value) => value.label,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => outputFileNameTemplate = value);
          },
        ),
      ],
    );
  }

  Widget buildEncoderSection() {
    return _SettingsForm(
      title: '编码器配置',
      children: [
        _FormFieldLabel('FFmpeg路径'),
        const SizedBox(height: 8),
        _SettingsPathField(
          controller: ffmpegPathController,
          enabled: true,
          highlighted: ffmpegPathDragging,
          hintText: '使用内置 FFmpeg',
          trailingTooltip: '选择 FFmpeg',
          onTrailingTap: pickFfmpegPath,
          onDraggingChanged: (value) {
            setState(() => ffmpegPathDragging = value);
          },
          onDropped: handleFfmpegPathDrop,
        ),
        const SizedBox(height: 18),
        _FormFieldLabel('FFprobe路径'),
        const SizedBox(height: 8),
        _SettingsPathField(
          controller: ffprobePathController,
          enabled: true,
          highlighted: ffprobePathDragging,
          hintText: '使用内置 FFprobe',
          trailingTooltip: '选择 FFprobe',
          onTrailingTap: pickFfprobePath,
          onDraggingChanged: (value) {
            setState(() => ffprobePathDragging = value);
          },
          onDropped: handleFfprobePathDrop,
        ),
      ],
    );
  }

  void updateVideoConfig(VideoProcessingConfig config) {
    setState(() {
      defaultMediaConfig = defaultMediaConfig.copyWith(video: config);
    });
  }

  void updateImageConfig(ImageProcessingConfig config) {
    setState(() {
      defaultMediaConfig = defaultMediaConfig.copyWith(image: config);
      if (imageQualityController.text != config.imageQuality.toString()) {
        imageQualityController.text = config.imageQuality.toString();
      }
    });
  }

  void updateAudioConfig(AudioProcessingConfig config) {
    setState(() {
      defaultMediaConfig = defaultMediaConfig.copyWith(audio: config);
    });
  }

  Future<void> pickOutputDirectory() async {
    final selectedPath = await widget.onPickOutputDirectory();
    if (!mounted || selectedPath == null || selectedPath.trim().isEmpty) {
      return;
    }
    setState(() => outputDirectoryController.text = selectedPath.trim());
  }

  Future<void> pickFfmpegPath() async {
    final selectedPath = await widget.onPickFfmpegPath();
    if (!mounted || selectedPath == null || selectedPath.trim().isEmpty) {
      return;
    }
    setState(() => ffmpegPathController.text = selectedPath.trim());
  }

  Future<void> pickFfprobePath() async {
    final selectedPath = await widget.onPickFfprobePath();
    if (!mounted || selectedPath == null || selectedPath.trim().isEmpty) {
      return;
    }
    setState(() => ffprobePathController.text = selectedPath.trim());
  }

  Future<void> handleOutputDirectoryDrop(List<DropItem> items) async {
    if (items.isEmpty) {
      return;
    }
    final item = items.first;
    final type = await FileSystemEntity.type(item.path);
    if (!mounted) {
      return;
    }
    setState(() {
      if (type == FileSystemEntityType.directory) {
        outputDirectoryController.text = item.path;
      }
      outputDirectoryDragging = false;
    });
  }

  Future<void> handleFfmpegPathDrop(List<DropItem> items) async {
    final droppedPath = await firstDroppedFilePath(items);
    if (!mounted) {
      return;
    }
    setState(() {
      if (droppedPath != null) {
        ffmpegPathController.text = droppedPath;
      }
      ffmpegPathDragging = false;
    });
  }

  Future<void> handleFfprobePathDrop(List<DropItem> items) async {
    final droppedPath = await firstDroppedFilePath(items);
    if (!mounted) {
      return;
    }
    setState(() {
      if (droppedPath != null) {
        ffprobePathController.text = droppedPath;
      }
      ffprobePathDragging = false;
    });
  }

  Future<String?> firstDroppedFilePath(List<DropItem> items) async {
    if (items.isEmpty) {
      return null;
    }
    final droppedPath = items.first.path.trim();
    if (droppedPath.isEmpty) {
      return null;
    }
    final type = await FileSystemEntity.type(droppedPath);
    if (type == FileSystemEntityType.file) {
      return droppedPath;
    }
    return null;
  }

  Future<void> confirmClearAppCache() async {
    final previewCallback = widget.onPreviewAppCacheCleanup;
    final clearCallback = widget.onClearAppCache;
    if (previewCallback == null || clearCallback == null) {
      return;
    }

    setState(() => clearingCache = true);
    try {
      final preview = await previewCallback();
      if (!mounted) {
        return;
      }

      if (preview.isEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => const _ConfirmMaintenanceDialog(
            title: '应用缓存为空',
            message: '当前没有可以清理的应用缓存。',
            confirmLabel: '知道了',
            singleAction: true,
          ),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _ConfirmMaintenanceDialog(
          title: '清空应用缓存',
          message:
              '将清理 ${preview.fileCount} 个文件、${preview.directoryCount} 个目录，'
              '预计释放 ${formatBytes(preview.totalBytes)}。该操作不会删除数据库、设置和导出文件。',
          confirmLabel: '清空缓存',
        ),
      );
      if (!mounted || confirmed != true) {
        return;
      }

      final result = await clearCallback();
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => _ConfirmMaintenanceDialog(
          title: '缓存已清理',
          message:
              '已删除 ${result.deletedFileCount} 个文件、'
              '${result.deletedDirectoryCount} 个目录，'
              '释放 ${formatBytes(result.releasedBytes)}。',
          confirmLabel: '完成',
          singleAction: true,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => clearingCache = false);
      }
    }
  }

  Future<void> confirmUninstallApp() async {
    final availabilityCallback = widget.onLoadAppUninstallAvailability;
    final launchCallback = widget.onLaunchCleanUninstaller;
    if (availabilityCallback == null || launchCallback == null) {
      return;
    }

    setState(() => uninstalling = true);
    try {
      final availability = await availabilityCallback();
      if (!mounted) {
        return;
      }

      if (!availability.available) {
        await showDialog<void>(
          context: context,
          builder: (context) => _ConfirmMaintenanceDialog(
            title: '无法卸载',
            message: availability.unavailableReason ?? '当前运行方式未找到安装器卸载信息。',
            confirmLabel: '知道了',
            singleAction: true,
          ),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => const _ConfirmMaintenanceDialog(
          title: '卸载 FrameLean',
          message:
              '确认后应用会关闭，并启动清理卸载脚本。脚本会删除应用程序、设置、数据库、缓存和注册表记录，'
              '不会扫描或删除你导出的媒体文件。',
          confirmLabel: '卸载应用',
          destructive: true,
        ),
      );
      if (!mounted || confirmed != true) {
        return;
      }

      await launchCallback();
    } finally {
      if (mounted) {
        setState(() => uninstalling = false);
      }
    }
  }

  Future<void> saveAndClose() async {
    if (saving) {
      return;
    }
    setState(() => saving = true);
    try {
      final video = videoConfig;
      final updatedConfig = defaultMediaConfig.copyWith(
        compressionMode: CompressionMode.preset,
        video: video,
        image: imageConfig,
        audio: audioConfig,
      );
      final outputDirectory = outputDirectoryController.text.trim();
      final ffmpegPath = ffmpegPathController.text.trim();
      final ffprobePath = ffprobePathController.text.trim();

      final updatedSettings = widget.initialSettings.copyWith(
        defaultOutputDirectory: saveOutputToSourceDirectory
            ? null
            : outputDirectory.isEmpty
            ? null
            : outputDirectory,
        saveOutputToSourceDirectory: saveOutputToSourceDirectory,
        customFfmpegPath: ffmpegPath.isEmpty ? null : ffmpegPath,
        customFfprobePath: ffprobePath.isEmpty ? null : ffprobePath,
        defaultOutputVideoCodec: video.videoCodec,
        defaultSmartPreset:
            video.smartPreset ?? SmartCompressionPreset.balanced,
        defaultMediaConfig: updatedConfig,
        defaultOutputFileNameTemplate: outputFileNameTemplate,
        themeMode: themeMode,
      );

      await widget.onSave(updatedSettings);
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface),
      child: child,
    );
  }
}

class _SettingsForm extends StatelessWidget {
  const _SettingsForm({
    required this.title,
    required this.children,
    this.maxWidth = 520,
  });

  final String title;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(31, 21, 31, 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 34),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({
    required this.selectedSection,
    required this.saving,
    required this.onClose,
    required this.onSectionSelected,
  });

  final _SettingsSection selectedSection;
  final bool saving;
  final VoidCallback onClose;
  final ValueChanged<_SettingsSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          21,
          WorkbenchConstants.appTopBarHeight,
          20,
          18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BackToWorkbenchButton(saving: saving, onPressed: onClose),
            const SizedBox(height: 34),
            _SidebarGroup(
              label: '常规配置',
              sections: const [_SettingsSection.app, _SettingsSection.about],
              selectedSection: selectedSection,
              onSectionSelected: onSectionSelected,
            ),
            const SizedBox(height: 30),
            _SidebarGroup(
              label: '任务设置',
              sections: const [
                _SettingsSection.video,
                _SettingsSection.image,
                _SettingsSection.audio,
              ],
              selectedSection: selectedSection,
              onSectionSelected: onSectionSelected,
            ),
            const SizedBox(height: 30),
            _SidebarGroup(
              label: '输入和输出',
              sections: const [
                _SettingsSection.output,
                _SettingsSection.encoder,
              ],
              selectedSection: selectedSection,
              onSectionSelected: onSectionSelected,
            ),
            const Spacer(),
            if (saving)
              Text(
                '正在保存...',
                style: TextStyle(color: colors.textTertiary, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

class _BackToWorkbenchButton extends StatelessWidget {
  const _BackToWorkbenchButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: saving ? null : onPressed,
      child: SizedBox(
        height: 26,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(
              Icons.chevron_left_rounded,
              color: colors.textPrimary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '返回工作台',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarGroup extends StatelessWidget {
  const _SidebarGroup({
    required this.label,
    required this.sections,
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final String label;
  final List<_SettingsSection> sections;
  final _SettingsSection selectedSection;
  final ValueChanged<_SettingsSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 9),
          child: Text(
            label,
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final section in sections) ...[
          _SidebarItem(
            section: section,
            selected: section == selectedSection,
            onTap: () => onSectionSelected(section),
          ),
          if (section != sections.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _SettingsSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Material(
      color: selected ? colors.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: SizedBox(
          height: 29,
          child: Row(
            children: [
              const SizedBox(width: 9),
              Icon(section.icon, color: colors.textPrimary, size: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDropdown<T> extends StatelessWidget {
  const _SettingsDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.itemLabel,
    required this.onChanged,
    this.width = 235,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ConfigDropdown<T>(
        label: label,
        trailingText: itemLabel(value),
        value: value,
        values: values,
        itemLabel: itemLabel,
        onChanged: onChanged,
        height: _AppSettingsViewState._fieldHeight,
        showTrailingText: false,
        labelFontSize: 12,
        valueFontSize: 12,
      ),
    );
  }
}

class _SettingsPathField extends StatelessWidget {
  const _SettingsPathField({
    required this.controller,
    required this.enabled,
    required this.highlighted,
    required this.hintText,
    required this.trailingTooltip,
    required this.onTrailingTap,
    required this.onDraggingChanged,
    required this.onDropped,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool highlighted;
  final String hintText;
  final String trailingTooltip;
  final VoidCallback onTrailingTap;
  final ValueChanged<bool> onDraggingChanged;
  final ValueChanged<List<DropItem>> onDropped;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: PathField(
        controller: controller,
        enabled: enabled,
        highlighted: highlighted,
        hintText: hintText,
        height: _AppSettingsViewState._fieldHeight,
        fontSize: 12,
        hintFontSize: 12,
        trailingIcon: Icons.more_horiz_rounded,
        trailingTooltip: trailingTooltip,
        onTrailingTap: onTrailingTap,
        onDraggingChanged: onDraggingChanged,
        onDropped: onDropped,
      ),
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  const _SettingsTextField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return SizedBox(
      width: 235,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FormFieldLabel(label),
          const SizedBox(height: 8),
          SizedBox(
            height: _AppSettingsViewState._fieldHeight,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              onChanged: onChanged,
              style: TextStyle(color: colors.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                filled: true,
                fillColor: colors.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCheckbox extends StatelessWidget {
  const _SettingsCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 15,
            child: Checkbox(
              value: value,
              onChanged: (next) => onChanged(next ?? false),
              side: BorderSide(color: colors.borderStrong),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TwoColumnFields extends StatelessWidget {
  const _TwoColumnFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: children[0]),
        ),
        const SizedBox(width: 36),
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: children[1]),
        ),
      ],
    );
  }
}

class _FormFieldLabel extends StatelessWidget {
  const _FormFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Text(
      label,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _AboutTextBlock extends StatelessWidget {
  const _AboutTextBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 11,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _AboutIconLinks extends StatelessWidget {
  const _AboutIconLinks({required this.onOpenLink});

  final AppSettingsExternalLinkCallback onOpenLink;

  static const _links = [
    _AboutIconLink(
      label: 'Gitee',
      assetPath: 'assets/icons/gitee.png',
      url: _frameLeanGiteeUrl,
    ),
    _AboutIconLink(
      label: 'GitHub',
      assetPath: 'assets/icons/github.png',
      url: _frameLeanGitHubUrl,
    ),
    _AboutIconLink(
      label: 'Gmail',
      assetPath: 'assets/icons/gmail.png',
      url: _frameLeanGmailUrl,
    ),
    _AboutIconLink(
      label: '掘金',
      assetPath: 'assets/icons/juejin.png',
      url: _frameLeanJuejinUrl,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final link in _links) ...[
          _AboutIconButton(
            label: link.label,
            assetPath: link.assetPath,
            onTap: () {
              unawaited(onOpenLink(link.url));
            },
          ),
          if (link != _links.last) const SizedBox(width: 17),
        ],
      ],
    );
  }
}

class _AboutIconLink {
  const _AboutIconLink({
    required this.label,
    required this.assetPath,
    required this.url,
  });

  final String label;
  final String assetPath;
  final String url;
}

class _AboutIconButton extends StatelessWidget {
  const _AboutIconButton({
    required this.label,
    required this.assetPath,
    required this.onTap,
  });

  final String label;
  final String assetPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Image.asset(assetPath, width: 20, height: 20),
          ),
        ),
      ),
    );
  }
}

class _MaintenanceButton extends StatelessWidget {
  const _MaintenanceButton({
    required this.label,
    required this.color,
    required this.foregroundColor,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final Color foregroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return SizedBox(
      width: 122,
      height: 28,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: colors.surfaceDisabled,
          disabledForegroundColor: colors.textTertiary,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _ConfirmMaintenanceDialog extends StatelessWidget {
  const _ConfirmMaintenanceDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.destructive = false,
    this.singleAction = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;
  final bool singleAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final actionColor = destructive ? colors.statusFailed : colors.primary;
    final foregroundColor = destructive ? colors.onDanger : colors.onPrimary;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(title),
      content: Text(message),
      actions: [
        if (!singleAction)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: actionColor,
            foregroundColor: foregroundColor,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

enum _CompletionSoundOption {
  none;

  String get label => switch (this) {
    _CompletionSoundOption.none => '不通知',
  };
}

enum _SettingsSection {
  app('应用设置', Icons.grid_view_rounded),
  about('关于', Icons.info_outline_rounded),
  video('视频任务', Icons.ondemand_video_rounded),
  image('图片任务', Icons.image_outlined),
  audio('音频任务', Icons.album_outlined),
  output('输出配置', Icons.output_rounded),
  encoder('编码器配置', Icons.build_rounded);

  const _SettingsSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

extension _AppThemeModeSettingsLabel on AppThemeMode {
  String get settingsLabel {
    return switch (this) {
      AppThemeMode.system => '跟随系统',
      AppThemeMode.light => '浅色',
      AppThemeMode.dark => '深色',
    };
  }
}

MediaTaskConfig _withAllMediaDefaults(MediaTaskConfig config) {
  final fallback = MediaTaskConfig.initialDefaults();
  return config.copyWith(
    video: config.video ?? fallback.video,
    image: config.image ?? fallback.image,
    audio: config.audio ?? fallback.audio,
  );
}

String formatBytes(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final fractionDigits = value >= 10 || unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
}
