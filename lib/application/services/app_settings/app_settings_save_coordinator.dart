import 'package:framelean/application/services/app_notifications/app_notification_manager.dart';
import 'package:framelean/application/services/app_settings/app_settings_save_target.dart';
import 'package:framelean/application/use_cases/app_settings/save_app_settings_use_case.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/app_notification_kind.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';

typedef AppThemeModeSetter = void Function(AppThemeMode mode);
typedef AppThemeCacheWriter = Future<void> Function(AppThemeMode mode);
typedef AppRuntimeInvalidator = void Function();
typedef ExistingTasksSettingsApplier =
    Future<void> Function(AppSettings settings);

class AppSettingsSaveCoordinator {
  const AppSettingsSaveCoordinator({
    required this.saveSettingsUseCase,
    required this.notificationManager,
    required this.setThemeMode,
    required this.writeThemeCache,
    required this.invalidateRuntime,
    required this.applySettingsToExistingTasks,
  });

  final SaveAppSettingsUseCase saveSettingsUseCase;
  final AppNotificationManager notificationManager;
  final AppThemeModeSetter setThemeMode;
  final AppThemeCacheWriter writeThemeCache;
  final AppRuntimeInvalidator invalidateRuntime;
  final ExistingTasksSettingsApplier applySettingsToExistingTasks;

  Future<void> save(
    AppSettings settings, {
    required AppSettingsSaveTarget target,
  }) {
    return notificationManager.track<void>(
      kind: AppNotificationKind.settings,
      source: 'settings',
      successTitle: target.successTitle,
      failureTitle: target.failureTitle,
      operation: () async {
        await saveSettingsUseCase.call(settings);
        setThemeMode(settings.themeMode);
        await writeThemeCache(settings.themeMode);
        invalidateRuntime();
        await applySettingsToExistingTasks(settings);
      },
    );
  }
}
