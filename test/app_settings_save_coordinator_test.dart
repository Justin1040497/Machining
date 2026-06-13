import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/repositories/app_notification_repository.dart';
import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/services/app_notifications/app_notification_manager.dart';
import 'package:framelean/application/services/app_settings/app_settings_save_coordinator.dart';
import 'package:framelean/application/services/app_settings/app_settings_save_target.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_locator.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_runtime.dart';
import 'package:framelean/application/use_cases/app_settings/save_app_settings_use_case.dart';
import 'package:framelean/domain/entities/app_notification_entry.dart';
import 'package:framelean/domain/entities/app_settings.dart';

void main() {
  test('task setting save does not refresh existing tasks', () async {
    final coordinator = _buildCoordinator();

    await coordinator.save(
      AppSettings.initial(),
      target: AppSettingsSaveTarget.videoTask,
    );

    expect(coordinator.appliedOutputSettings, isEmpty);
    expect(
      coordinator.notificationRepository.savedNotifications.single.title,
      '视频任务配置已保存',
    );
    expect(
      coordinator.notificationRepository.savedNotifications.single.message,
      '在下次导入任务时应用',
    );
  });

  test('output setting save refreshes existing non-running tasks', () async {
    final coordinator = _buildCoordinator();
    final settings = AppSettings.initial().copyWith(
      defaultOutputDirectory: '/exports',
      saveOutputToSourceDirectory: false,
    );

    await coordinator.save(settings, target: AppSettingsSaveTarget.output);

    expect(coordinator.appliedOutputSettings, [settings]);
    expect(
      coordinator.notificationRepository.savedNotifications.single.title,
      '输出配置已保存',
    );
    expect(
      coordinator.notificationRepository.savedNotifications.single.message,
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
  final appliedOutputSettings = <AppSettings>[];
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
    applyOutputSettingsToExistingTasks: (settings) async {
      appliedOutputSettings.add(settings);
    },
  );

  return _CoordinatorHarness(
    coordinator: coordinator,
    notificationRepository: notificationRepository,
    appliedOutputSettings: appliedOutputSettings,
  );
}

class _CoordinatorHarness {
  const _CoordinatorHarness({
    required this.coordinator,
    required this.notificationRepository,
    required this.appliedOutputSettings,
  });

  final AppSettingsSaveCoordinator coordinator;
  final _FakeAppNotificationRepository notificationRepository;
  final List<AppSettings> appliedOutputSettings;

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
  Stream<List<AppNotificationEntry>> watchRecentNotifications({
    int? limit,
  }) async* {
    yield savedNotifications.take(limit ?? savedNotifications.length).toList();
  }
}
