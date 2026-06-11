import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/app/theme/app_theme_controller.dart';
import 'package:framelean/application/services/app_settings/app_settings_save_coordinator.dart';
import 'package:framelean/application/use_cases/app_settings/save_app_settings_use_case.dart';
import 'package:framelean/features/workbench/providers/media_task_notifier.dart';
import 'package:framelean/infrastructure/providers/app_notification_provider.dart';
import 'package:framelean/infrastructure/providers/input_runtime_provider.dart';
import 'package:framelean/infrastructure/providers/repository_provider.dart';
import 'package:framelean/infrastructure/services/theme_prefs_cache.dart';

final appSettingsSaveCoordinatorProvider = Provider<AppSettingsSaveCoordinator>(
  (ref) {
    return AppSettingsSaveCoordinator(
      saveSettingsUseCase: SaveAppSettingsUseCase(
        repository: ref.watch(appSettingsRepositoryProvider),
        ffmpegLocator: ref.watch(ffmpegLocatorProvider),
      ),
      notificationManager: ref.watch(appNotificationManagerProvider),
      setThemeMode: (mode) {
        ref.read(appThemeModeProvider.notifier).setThemeMode(mode);
      },
      writeThemeCache: ThemePrefsCache.write,
      invalidateRuntime: () {
        ref.invalidate(ffmpegRuntimeProvider);
      },
      applySettingsToExistingTasks: (settings) {
        return ref
            .read(mediaTaskListProvider.notifier)
            .applySettingsToExistingTasks(settings);
      },
    );
  },
);
