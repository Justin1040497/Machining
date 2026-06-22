import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:framelean/app/constants.dart';
import 'package:framelean/application/services/app_maintenance/app_cache_cleaner.dart';
import 'package:framelean/application/services/framelean_build_info.dart';
import 'package:framelean/application/services/app_settings/app_settings_save_target.dart';
import 'package:framelean/application/use_cases/app_maintenance/clear_app_cache_use_case.dart';
import 'package:framelean/application/use_cases/app_maintenance/preview_app_cache_cleanup_use_case.dart';
import 'package:framelean/application/use_cases/app_settings/load_app_settings_use_case.dart';
import 'package:framelean/app/presentation/widgets/sidebar_page_scaffold.dart';
import 'package:framelean/app/providers/platform_provider.dart';
import 'package:framelean/app/presentation/widgets/percentage_slider_panel.dart';
import 'package:framelean/app/presentation/widgets/update_restart_warning_dialog.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/domain/enums/app_notification_kind.dart';
import 'package:framelean/domain/enums/app_update_status.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:framelean/domain/enums/app_close_behavior.dart';
import 'package:framelean/domain/enums/app_shortcut_action.dart';
import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/notification_delivery_mode.dart';
import 'package:framelean/domain/enums/notification_event_type.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/task_completion_sound.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/app_shortcut_binding.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/app_update_state.dart';
import 'package:framelean/domain/value_objects/video_processing_config.dart';
import 'package:framelean/domain/value_objects/video_output_compatibility.dart';
import 'package:framelean/app/shortcuts/app_hotkey_adapter.dart';
import 'package:framelean/app/presentation/domain_labels.dart';
import 'package:framelean/app/shortcuts/app_shortcut_resolver.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:framelean/app/presentation/widgets/app_dialog_frame.dart';
import 'package:framelean/app/presentation/widgets/form_controls/config_dropdown.dart';
import 'package:framelean/app/presentation/widgets/form_controls/path_field.dart';
import 'package:framelean/app/providers/app_maintenance_provider.dart';
import 'package:framelean/app/providers/app_notification_provider.dart';
import 'package:framelean/app/providers/app_settings_provider.dart';
import 'package:framelean/app/providers/app_settings_save_provider.dart';
import 'package:framelean/app/providers/app_update_provider.dart';
import 'package:framelean/app/providers/repository_provider.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

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
typedef AppSettingsExternalLinkCallback = Future<void> Function(String url);

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

  Future<void> installUpdateWithTaskCheck() async {
    if (ref.read(isManualMacosUpdateProvider)) {
      await ref.read(appUpdateProvider.notifier).installDownloadedUpdate();
      return;
    }

    final tasks = await ref.read(mediaTaskRepositoryProvider).loadAllTasks();
    final hasUnfinishedTasks = tasks.any(_taskNeedsUpdateRestartWarning);
    if (hasUnfinishedTasks && mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => const UpdateRestartWarningDialog(),
      );
      if (confirmed != true) {
        return;
      }
    }

    await ref.read(appUpdateProvider.notifier).installDownloadedUpdate();
  }

  Future<void> checkUpdateAndOpenReleaseNotes() async {
    await ref.read(appUpdateProvider.notifier).checkForUpdate();
    if (!mounted) {
      return;
    }

    final updateState = ref.read(appUpdateProvider).asData?.value;
    final release = updateState?.release;
    if (release == null || updateState?.status == AppUpdateStatus.failed) {
      return;
    }

    context.push('/settings/release-notes?version=${release.version}&from=settings');
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
      source: notificationSourceSettings,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final fileSelectionService = ref.read(fileSelectionServiceProvider);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!mounted) return;
          if (ModalRoute.of(context)?.isCurrent != true) return;
          returnToWorkbench();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: colors.surface,
          body: FutureBuilder<AppSettings>(
            future: settingsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final updateState =
                    ref.watch(appUpdateProvider).asData?.value ??
                    AppUpdateState.initial();
                final manualMacosUpdate = ref.watch(
                  isManualMacosUpdateProvider,
                );
                return AppSettingsView(
                  initialSettings: snapshot.requireData,
                  fallbackDefaultDirectory:
                      fileSelectionService.defaultExportPath,
                  updateState: updateState,
                  manualMacosUpdate: manualMacosUpdate,
                  onPickOutputDirectory:
                      fileSelectionService.pickOutputDirectory,
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
                  onOpenExternalLink: openExternalLink,
                  onCheckUpdate: checkUpdateAndOpenReleaseNotes,
                  onStartOrResumeUpdateDownload: () {
                    return ref
                        .read(appUpdateProvider.notifier)
                        .startOrResumeDownload();
                  },
                  onPauseUpdateDownload: () {
                    ref.read(appUpdateProvider.notifier).pauseDownload();
                  },
                  onInstallUpdate: installUpdateWithTaskCheck,
                  onOpenReleaseNotes: () {
                    context.push('/settings/release-notes?from=settings');
                  },
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
        ),
      ),
    );
  }
}

bool _taskNeedsUpdateRestartWarning(MediaTask task) {
  return task.status == TaskStatus.running ||
      task.status == TaskStatus.paused ||
      task.status == TaskStatus.pending ||
      task.status == TaskStatus.analyzing;
}

class AppSettingsView extends StatefulWidget {
  const AppSettingsView({
    super.key,
    required this.initialSettings,
    required this.fallbackDefaultDirectory,
    required this.updateState,
    this.manualMacosUpdate = false,
    required this.onPickOutputDirectory,
    required this.onPickFfmpegPath,
    required this.onPickFfprobePath,
    required this.onSave,
    this.onClose,
    this.onPreviewAppCacheCleanup,
    this.onClearAppCache,
    this.onOpenExternalLink,
    this.onCheckUpdate,
    this.onStartOrResumeUpdateDownload,
    this.onPauseUpdateDownload,
    this.onInstallUpdate,
    this.onOpenReleaseNotes,
  });

  final AppSettings initialSettings;
  final String fallbackDefaultDirectory;
  final AppUpdateState updateState;
  final bool manualMacosUpdate;
  final AppSettingsPathPicker onPickOutputDirectory;
  final AppSettingsPathPicker onPickFfmpegPath;
  final AppSettingsPathPicker onPickFfprobePath;
  final AppSettingsSaveCallback onSave;
  final VoidCallback? onClose;
  final AppCacheCleanupPreviewCallback? onPreviewAppCacheCleanup;
  final AppCacheCleanupCallback? onClearAppCache;
  final AppSettingsExternalLinkCallback? onOpenExternalLink;
  final Future<void> Function()? onCheckUpdate;
  final Future<void> Function()? onStartOrResumeUpdateDownload;
  final VoidCallback? onPauseUpdateDownload;
  final Future<void> Function()? onInstallUpdate;
  final VoidCallback? onOpenReleaseNotes;

  @override
  State<AppSettingsView> createState() => _AppSettingsViewState();
}

class _AppSettingsViewState extends State<AppSettingsView> {
  static const _sidebarWidth = 168.0;
  static const _fieldHeight = 40.0;

  late _SettingsSection selectedSection;
  late AppThemeMode themeMode;
  late TaskCompletionSound completionSound;
  late bool hideNotificationBadge;
  late int maxConcurrentExecutions;
  late int folderImportScanDepth;
  late AppCloseBehavior closeBehavior;
  late Map<NotificationEventType, NotificationDeliveryMode>
  notificationPolicies;
  late Map<AppShortcutAction, AppShortcutBinding> shortcutBindings;
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
  String? shortcutConflictMessage;

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
    maxConcurrentExecutions = widget.initialSettings.maxConcurrentExecutions;
    folderImportScanDepth = widget.initialSettings.folderImportScanDepth;
    closeBehavior = widget.initialSettings.closeBehavior;
    notificationPolicies = Map.of(widget.initialSettings.notificationPolicies);
    shortcutBindings = Map.of(widget.initialSettings.shortcutBindings);
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
    return SidebarPageScaffold(
      backTitle: '返回工作台',
      onBackPressed: closePage,
      isBackLoading: savingSection != null,
      sidebarPadding: const EdgeInsets.fromLTRB(
        21, topBarHeight, 20, 18,
      ),
      sidebarWidth: _sidebarWidth,
      sidebar: _SettingsSidebar(
        selectedSection: selectedSection,
        saving: savingSection != null,
        onSectionSelected: (section) {
          _revertCurrentSectionIfDirty();
          setState(() => selectedSection = section);
        },
      ),
      content: _SettingsContent(child: buildSelectedSection()),
    );
  }
}
