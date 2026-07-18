import 'package:framelean/application/constants.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/application/services/app_notifications/app_notification_manager.dart';
import 'package:framelean/application/services/app_settings/app_settings_save_target.dart';
import 'package:framelean/application/use_cases/app_settings/apply_output_settings_to_existing_tasks_use_case.dart';
import 'package:framelean/application/use_cases/app_settings/save_app_settings_use_case.dart';

typedef AppThemeModeSetter = void Function(AppThemeMode mode);
typedef AppThemeCacheWriter = Future<void> Function(AppThemeMode mode);
typedef AppRuntimeInvalidator = void Function();
typedef OutputSettingsAppliedCallback = void Function();

class AppSettingsSaveCoordinator {
  const AppSettingsSaveCoordinator({
    required this.saveSettingsUseCase,
    required this.notificationManager,
    required this.setThemeMode,
    required this.writeThemeCache,
    required this.invalidateRuntime,
    required this.applyOutputSettingsUseCase,
    required this.onOutputSettingsApplied,
  });

  final SaveAppSettingsUseCase saveSettingsUseCase;
  final AppNotificationManager notificationManager;
  final AppThemeModeSetter setThemeMode;
  final AppThemeCacheWriter writeThemeCache;
  final AppRuntimeInvalidator invalidateRuntime;
  final ApplyOutputSettingsToExistingTasksUseCase applyOutputSettingsUseCase;
  final OutputSettingsAppliedCallback onOutputSettingsApplied;

  Future<void> save(
    AppSettings settings, {
    required AppSettingsSaveTarget target,
  }) {
    return notificationManager.track<void>(
      kind: AppNotificationKind.settings,
      source: notificationSourceSettings,
      successTitle: target.successTitle,
      successMessage: target.successMessage,
      failureTitle: target.failureTitle,
      operation: () async {
        await saveSettingsUseCase.call(settings);
        setThemeMode(settings.themeMode);
        await writeThemeCache(settings.themeMode);
        invalidateRuntime();
        if (target.refreshesExistingTasks) {
          await applyOutputSettingsUseCase.call(settings);
          onOutputSettingsApplied();
        }
      },
    );
  }
}
