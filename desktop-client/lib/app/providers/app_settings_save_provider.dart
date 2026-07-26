import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/app/theme/app_theme_controller.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/features/workbench/library.dart';
import 'package:framelean/app/providers/app_notification_provider.dart';
import 'package:framelean/app/providers/input_runtime_provider.dart';
import 'package:framelean/app/providers/platform_provider.dart';
import 'package:framelean/app/providers/repository_provider.dart';

final appSettingsSaveCoordinatorProvider = Provider<AppSettingsSaveCoordinator>(
  (ref) {
    return AppSettingsSaveCoordinator(
      saveSettingsUseCase: SaveAppSettingsUseCase(
        repository: ref.watch(appSettingsRepositoryProvider),
      ),
      notificationManager: ref.watch(appNotificationManagerProvider),
      setThemeMode: (mode) {
        ref.read(appThemeModeProvider.notifier).setThemeMode(mode);
      },
      writeThemeCache: ref.watch(themePreferencesCacheProvider).write,
      invalidateRuntime: () {
        ref.invalidate(ffmpegRuntimeProvider);
      },
      applyOutputSettingsUseCase: ApplyOutputSettingsToExistingTasksUseCase(
        repository: ref.watch(mediaTaskRepositoryProvider),
      ),
      onOutputSettingsApplied: () {
        ref.invalidate(mediaTaskListProvider);
      },
    );
  },
);
