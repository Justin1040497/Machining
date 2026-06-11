import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:framelean/application/services/app_maintenance/app_cache_cleaner.dart';
import 'package:framelean/application/services/app_maintenance/app_uninstaller.dart';
import 'package:framelean/application/services/framelean_build_info.dart';
import 'package:framelean/application/use_cases/app_maintenance/clear_app_cache_use_case.dart';
import 'package:framelean/application/use_cases/app_maintenance/launch_clean_uninstaller_use_case.dart';
import 'package:framelean/application/use_cases/app_maintenance/load_app_uninstall_availability_use_case.dart';
import 'package:framelean/application/use_cases/app_maintenance/preview_app_cache_cleanup_use_case.dart';
import 'package:framelean/application/use_cases/app_settings/load_app_settings_use_case.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
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
import 'package:framelean/infrastructure/providers/app_maintenance_provider.dart';
import 'package:framelean/infrastructure/providers/app_notification_provider.dart';
import 'package:framelean/infrastructure/providers/app_settings_save_provider.dart';
import 'package:framelean/infrastructure/providers/repository_provider.dart';
import 'package:path/path.dart' as path;

part 'sections/settings_sections.dart';
part 'sections/settings_section_actions.dart';
part 'sections/settings_section_state.dart';
part 'widgets/settings_page_widgets.dart';
part 'widgets/settings_form_widgets.dart';
part 'widgets/settings_about_widgets.dart';

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
    await ref.read(appSettingsSaveCoordinatorProvider).save(settings);
  }

  Future<void> launchCleanUninstaller() async {
    await LaunchCleanUninstallerUseCase(
      uninstaller: ref.read(appUninstallerProvider),
    ).call(currentProcessId: pid);
    exit(0);
  }

  Future<void> openExternalLink(String url) async {
    final notificationManager = ref.read(appNotificationManagerProvider);
    final result = await WorkbenchExternalLinkOpener.open(url);
    if (result.succeeded) {
      return;
    }

    await notificationManager.notify(
      level: AppNotificationLevel.error,
      title: '打开链接失败',
      message: result.message!,
      source: 'settings',
    );
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
              onClose: () => returnToWorkbench(),
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
    this.onClose,
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
  final VoidCallback? onClose;
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
  late AppSettings savedSettings;
  _SettingsSection? savingSection;
  bool clearingCache = false;
  bool uninstalling = false;

  VideoProcessingConfig get videoConfig =>
      defaultMediaConfig.video ?? VideoProcessingConfig.initial();

  ImageProcessingConfig get imageConfig =>
      defaultMediaConfig.image ?? ImageProcessingConfig.initial();

  AudioProcessingConfig get audioConfig =>
      defaultMediaConfig.audio ?? AudioProcessingConfig.initial();

  void updateViewState(VoidCallback update) {
    setState(update);
  }

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

    savedSettings = widget.initialSettings;
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
            // 侧边栏
            SizedBox(
              width: _sidebarWidth,
              child: _SettingsSidebar(
                selectedSection: selectedSection,
                saving: savingSection != null,
                onClose: closePage,
                onSectionSelected: (section) {
                  _revertCurrentSectionIfDirty();
                  setState(() => selectedSection = section);
                },
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: colors.border),
            // 内容区域
            Expanded(child: _SettingsContent(child: buildSelectedSection())),
          ],
        ),
      ),
    );
  }
}
