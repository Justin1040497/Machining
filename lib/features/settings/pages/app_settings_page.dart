import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:framelean/application/services/app_maintenance/app_cache_cleaner.dart';
import 'package:framelean/application/services/app_maintenance/app_uninstaller.dart';
import 'package:framelean/application/services/framelean_build_info.dart';
import 'package:framelean/application/services/app_settings/app_settings_save_target.dart';
import 'package:framelean/application/use_cases/app_maintenance/clear_app_cache_use_case.dart';
import 'package:framelean/application/use_cases/app_maintenance/launch_clean_uninstaller_use_case.dart';
import 'package:framelean/application/use_cases/app_maintenance/load_app_uninstall_availability_use_case.dart';
import 'package:framelean/application/use_cases/app_maintenance/preview_app_cache_cleanup_use_case.dart';
import 'package:framelean/application/use_cases/app_settings/load_app_settings_use_case.dart';
import 'package:framelean/app/presentation/app_layout_constants.dart';
import 'package:framelean/app/presentation/media_configuration_ui_constants.dart';
import 'package:framelean/app/providers/platform_provider.dart';
import 'package:framelean/app/widgets/percentage_slider_panel.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/domain/enums/app_notification_kind.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/task_completion_sound.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/video_processing_config.dart';
import 'package:framelean/app/presentation/domain_labels.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:framelean/app/widgets/form_controls/config_dropdown.dart';
import 'package:framelean/app/widgets/form_controls/path_field.dart';
import 'package:framelean/app/providers/app_maintenance_provider.dart';
import 'package:framelean/app/providers/app_notification_provider.dart';
import 'package:framelean/app/providers/app_settings_provider.dart';
import 'package:framelean/app/providers/app_settings_save_provider.dart';
import 'package:framelean/app/providers/repository_provider.dart';

part '../sections/settings_sections.dart';
part '../sections/settings_section_actions.dart';
part '../sections/settings_section_state.dart';
part '../widgets/settings_page_widgets.dart';
part '../widgets/settings_form_widgets.dart';
part '../widgets/settings_about_widgets.dart';

typedef AppSettingsSaveCallback =
    Future<void> Function(AppSettings settings, AppSettingsSaveTarget target);
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

  Future<void> saveSettings(
    AppSettings settings,
    AppSettingsSaveTarget target,
  ) async {
    await ref
        .read(appSettingsSaveCoordinatorProvider)
        .save(settings, target: target);
    ref.invalidate(appSettingsProvider);
  }

  Future<void> launchCleanUninstaller() async {
    await LaunchCleanUninstallerUseCase(
      uninstaller: ref.read(appUninstallerProvider),
    ).call(currentProcessId: pid);
    exit(0);
  }

  Future<void> openExternalLink(String url) async {
    final notificationManager = ref.read(appNotificationManagerProvider);
    final result = await ref.read(externalLinkOpenerProvider).open(url);
    if (result.succeeded) {
      return;
    }

    await notificationManager.notify(
      kind: AppNotificationKind.settings,
      level: AppNotificationLevel.error,
      title: '打开链接失败',
      message: result.message!,
      source: 'settings',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final fileSelectionService = ref.read(fileSelectionServiceProvider);
    return Scaffold(
      backgroundColor: colors.surface,
      body: FutureBuilder<AppSettings>(
        future: settingsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return AppSettingsView(
              initialSettings: snapshot.requireData,
              fallbackDefaultDirectory: fileSelectionService.defaultExportPath,
              onPickOutputDirectory: fileSelectionService.pickOutputDirectory,
              onPickFfmpegPath: fileSelectionService.pickExecutablePath,
              onPickFfprobePath: fileSelectionService.pickExecutablePath,
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
  late TaskCompletionSound completionSound;
  late bool hideNotificationBadge;
  late bool showTaskCompletionDialog;
  late bool saveOutputToSourceDirectory;
  late MediaTaskConfig defaultMediaConfig;

  late final TextEditingController outputDirectoryController;
  late final TextEditingController outputFileNameTemplateController;
  late final TextEditingController ffmpegPathController;
  late final TextEditingController ffprobePathController;

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
    completionSound = widget.initialSettings.taskCompletionSound;
    hideNotificationBadge = widget.initialSettings.hideNotificationBadge;
    showTaskCompletionDialog = widget.initialSettings.showTaskCompletionDialog;
    saveOutputToSourceDirectory =
        widget.initialSettings.saveOutputToSourceDirectory;
    defaultMediaConfig = _withAllMediaDefaults(
      widget.initialSettings.defaultMediaConfig,
    );

    outputDirectoryController = TextEditingController(
      text:
          widget.initialSettings.defaultOutputDirectory ??
          widget.fallbackDefaultDirectory,
    );
    outputFileNameTemplateController = TextEditingController(
      text: widget.initialSettings.defaultOutputFileNameTemplate,
    );
    ffmpegPathController = TextEditingController(
      text: widget.initialSettings.customFfmpegPath ?? '',
    );
    ffprobePathController = TextEditingController(
      text: widget.initialSettings.customFfprobePath ?? '',
    );
    savedSettings = widget.initialSettings;
  }

  @override
  void dispose() {
    outputDirectoryController.dispose();
    outputFileNameTemplateController.dispose();
    ffmpegPathController.dispose();
    ffprobePathController.dispose();
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
