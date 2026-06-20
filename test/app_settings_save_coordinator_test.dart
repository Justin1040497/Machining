import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/app_notifications/app_notification_manager.dart';
import 'package:framelean/application/services/app_settings/app_settings_save_coordinator.dart';
import 'package:framelean/application/services/app_settings/app_settings_save_target.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_locator.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_runtime.dart';
import 'package:framelean/application/use_cases/app_settings/apply_output_settings_to_existing_tasks_use_case.dart';
import 'package:framelean/application/use_cases/app_settings/save_app_settings_use_case.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/entities/media_task.dart';

void main() {
  test('task setting save does not refresh existing tasks', () async {
    final coordinator = _buildCoordinator();
    final presentationFuture =
        coordinator.notificationManager.presentations.first;

    await coordinator.save(
      AppSettings.initial(),
      target: AppSettingsSaveTarget.videoTask,
    );
    final presentation = await presentationFuture;

    expect(coordinator.outputSettingsAppliedCount, 0);
    expect(coordinator.notificationRepository.savedNotifications, isEmpty);
    expect(presentation.notification.title, '视频任务配置已保存');
    expect(presentation.notification.message, '在下次导入任务时应用');
  });

  test('output setting save refreshes existing non-running tasks', () async {
    final coordinator = _buildCoordinator();
    final presentationFuture =
        coordinator.notificationManager.presentations.first;
    final settings = AppSettings.initial().copyWith(
      defaultOutputDirectory: '/exports',
      saveOutputToSourceDirectory: false,
    );

    await coordinator.save(settings, target: AppSettingsSaveTarget.output);
    final presentation = await presentationFuture;

    expect(coordinator.outputSettingsAppliedCount, 1);
    expect(coordinator.notificationRepository.savedNotifications, isEmpty);
    expect(presentation.notification.title, '输出配置已保存');
    expect(
      presentation.notification.message,
      '非运行状态的任务已更新；正在处理的任务将在下次处理时使用新配置',
    );
  });
}

_CoordinatorHarness _buildCoordinator() {
  final settingsRepository = _FakeAppSettingsRepository(AppSettings.initial());
  final notificationRepository = _FakeAppNotificationRepository();
  final notificationManager = AppNotificationManager(
    repository: notificationRepository,
  );
  var outputSettingsAppliedCount = 0;
  addTearDown(notificationManager.dispose);

  final coordinator = AppSettingsSaveCoordinator(
    saveSettingsUseCase: SaveAppSettingsUseCase(
      repository: settingsRepository,
      ffmpegLocator: _FakeFfmpegLocator(),
    ),
    notificationManager: notificationManager,
    setThemeMode: (_) {},
    writeThemeCache: (_) async {},
    invalidateRuntime: () {},
    applyOutputSettingsUseCase: ApplyOutputSettingsToExistingTasksUseCase(
      repository: _FakeMediaTaskRepository(),
    ),
    onOutputSettingsApplied: () {
      outputSettingsAppliedCount += 1;
    },
  );

  return _CoordinatorHarness(
    coordinator: coordinator,
    notificationManager: notificationManager,
    notificationRepository: notificationRepository,
    readOutputSettingsAppliedCount: () => outputSettingsAppliedCount,
  );
}

class _CoordinatorHarness {
  const _CoordinatorHarness({
    required this.coordinator,
    required this.notificationManager,
    required this.notificationRepository,
    required this.readOutputSettingsAppliedCount,
  });

  final AppSettingsSaveCoordinator coordinator;
  final AppNotificationManager notificationManager;
  final _FakeAppNotificationRepository notificationRepository;
  final int Function() readOutputSettingsAppliedCount;

  int get outputSettingsAppliedCount => readOutputSettingsAppliedCount();

  Future<void> save(
    AppSettings settings, {
    required AppSettingsSaveTarget target,
  }) {
    return coordinator.save(settings, target: target);
  }
}

class _FakeAppSettingsRepository implements AppSettingsRepository {
  _FakeAppSettingsRepository(this.settings);

  AppSettings settings;

  @override
  Future<AppSettings> loadSettings() async {
    return settings;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    this.settings = settings;
  }
}

class _FakeMediaTaskRepository implements MediaTaskRepository {
  @override
  Future<void> deleteTaskById(String taskId) async {}

  @override
  Future<List<MediaTask>> loadAllTasks() async => const [];

  @override
  Future<void> replaceAllTasks(List<MediaTask> tasks) async {}

  @override
  Future<void> saveTask(MediaTask task) async {}

  @override
  Future<void> updateTaskSortOrders(
    List<MediaTaskSortOrderUpdate> updates,
  ) async {}

  @override
  Future<void> updateTaskFolderSortOrders(
    List<MediaTaskFolderSortOrderUpdate> updates,
  ) async {}
}

class _FakeFfmpegLocator implements FfmpegLocator {
  @override
  Future<ResolvedFfmpegRuntime> resolve({
    String? customFfmpegPath,
    String? customFfprobePath,
  }) async {
    return const ResolvedFfmpegRuntime(ffmpeg: null, ffprobe: null);
  }

  @override
  Future<ResolvedFfmpegTool> validateCustomFfmpegPath(String inputPath) async {
    return ResolvedFfmpegTool(
      path: inputPath,
      source: FfmpegBinarySource.custom,
    );
  }

  @override
  Future<ResolvedFfmpegTool> validateCustomFfprobePath(String inputPath) async {
    return ResolvedFfmpegTool(
      path: inputPath,
      source: FfmpegBinarySource.custom,
    );
  }
}

class _FakeAppNotificationRepository implements AppNotificationRepository {
  final savedNotifications = <AppNotificationEntry>[];

  @override
  Future<void> dismiss(String id, DateTime dismissedAt) async {}

  @override
  Future<void> dismissAll(DateTime dismissedAt) async {
    savedNotifications.clear();
  }

  @override
  Future<List<AppNotificationEntry>> loadRecentNotifications({
    int? limit,
  }) async {
    return savedNotifications.take(limit ?? savedNotifications.length).toList();
  }

  @override
  Future<void> markAsRead(String id, DateTime readAt) async {}

  @override
  Future<void> markAllAsRead(DateTime readAt) async {}

  @override
  Future<void> saveNotification(AppNotificationEntry notification) async {
    savedNotifications.add(notification);
  }

  @override
  Future<AppNotificationEntry> upsertNotificationByDedupeKey(
    AppNotificationEntry notification,
  ) async {
    savedNotifications.removeWhere(
      (item) =>
          item.dedupeKey != null && item.dedupeKey == notification.dedupeKey,
    );
    savedNotifications.add(notification);
    return notification;
  }

  @override
  Stream<List<AppNotificationEntry>> watchRecentNotifications({
    int? limit,
  }) async* {
    yield savedNotifications.take(limit ?? savedNotifications.length).toList();
  }
}
