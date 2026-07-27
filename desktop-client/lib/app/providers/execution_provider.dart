import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/infrastructure/library.dart';
import 'package:framelean/app/providers/app_notification_provider.dart';
import 'package:framelean/app/providers/engine_provider.dart';
import 'package:framelean/app/providers/repository_provider.dart';
import 'package:path/path.dart' as path;

final executionResourceGuardProvider = Provider<ExecutionResourceGuard>((ref) {
  return const LocalExecutionResourceGuard();
});

/// 全局媒体工作资源调度器，管理所有媒体工作的资源分配。
final mediaWorkSchedulerProvider = Provider<MediaWorkScheduler>((ref) {
  final monitor = ref.read(mediaResourceMonitorProvider);
  monitor.start();

  final scheduler = MediaWorkScheduler(resourceMonitor: monitor);
  ref.onDispose(() {
    unawaited(scheduler.stop());
    unawaited(monitor.stop());
  });
  return scheduler;
});

/// 全局系统资源监控器，每 1 秒采样内存，计算压力级别。
final mediaResourceMonitorProvider = Provider<MediaResourceMonitor>((ref) {
  return MediaResourceMonitor();
});

/// Client-side analysis submission coordinator. FEngine owns the external
/// work queue and FLL owns the actual analysis.
final mediaAnalysisQueueProvider = Provider<MediaAnalysisQueue>((ref) {
  final queue = MediaAnalysisQueue(
    analyzeTask: (taskId) async {
      final repository = ref.read(mediaTaskRepositoryProvider);
      final projectionRepository = ref.read(
        engineAnalysisProjectionRepositoryProvider,
      );

      final useCase = AnalyzeMediaTaskUseCase(
        repository: repository,
        analysisProjectionRepository: projectionRepository,
        readEngineGateway: () => ref.read(engineGatewayProvider.future),
      );

      return useCase.call(taskId);
    },
  );

  ref.onDispose(() {
    // 容器销毁时停止队列，防止子进程泄漏
    unawaited(queue.stop());
  });

  return queue;
});

/// Engine execution submission is a process-boundary operation. The provider
/// keeps one use-case instance so duplicate submissions for the same task can
/// be rejected while a request is in flight.
final submitEngineExecutionUseCaseProvider =
    Provider<SubmitEngineExecutionUseCase>((ref) {
      return SubmitEngineExecutionUseCase(
        repository: ref.read(mediaTaskRepositoryProvider),
        analysisProjectionRepository: ref.read(
          engineAnalysisProjectionRepositoryProvider,
        ),
        settingsRepository: ref.read(appSettingsRepositoryProvider),
        readEngineGateway: () => ref.read(engineGatewayProvider.future),
        onTaskFailed: (task) async {
          await ref.read(appNotificationManagerProvider).notifyTaskFailed(task);
        },
      );
    });

/// Routes all Client execution requests to the FEngine process boundary.
///
/// The legacy runner provider remains available to migration-only controls
/// (pause, cancellation and cleanup) until those surfaces move to Engine APIs.
/// It is intentionally not injected into the execution coordinator.
final mediaTaskExecutionCoordinatorProvider =
    Provider<MediaTaskExecutionCoordinator>((ref) {
      return MediaTaskExecutionCoordinator(
        repository: ref.read(mediaTaskRepositoryProvider),
        analysisProjectionRepository: ref.read(
          engineAnalysisProjectionRepositoryProvider,
        ),
        taskFolderRepository: ref.read(taskFolderRepositoryProvider),
        submitEngineExecution: ref.read(submitEngineExecutionUseCaseProvider),
        readEngineGateway: () => ref.read(engineGatewayProvider.future),
      );
    });

final executionLogStoreProvider = Provider<ExecutionLogStore>((ref) {
  return ExecutionLogStore(logsDirectory: engineExecutionLogsDirectory());
});

Directory engineExecutionLogsDirectory() {
  return Directory(path.join(Directory.systemTemp.path, engineLogsSubDir));
}
